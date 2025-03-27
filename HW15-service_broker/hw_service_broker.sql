USE [WideWorldImporters];

--Создадим дополнительную колонку для визуального восприятия работы брокера
ALTER TABLE Sales.Invoices
ADD InvoiceConfirmedForProcessing DATETIME;

USE [WideWorldImporters];
Select * FROM Sales.Invoices

--Service Broker включен ли?
select name, is_broker_enabled
from sys.databases;

--Включить брокер
USE master
ALTER DATABASE TestForServiceBroker
SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE; --NO WAIT --prod (в однопользовательском режиме!!! На проде так не нужно)

--БД должна функционировать от имени технической учетки!!!
ALTER AUTHORIZATION
ON DATABASE::WideWorldImporters TO [ServiceBrokerUser];

ALTER AUTHORIZATION
ON DATABASE::TestForServiceBroker TO [ServiceBrokerUser];

--Включите это чтобы доверять сервисам без использования сертификатов когда работаем между различными
--БД и инстансами(фактически говорим серверу, что этой БД можно доверять)
--Если мы открепим БД и вновь ее прикрепим, то это свойство сбросится в OFF
ALTER DATABASE WideWorldImporters SET TRUSTWORTHY ON;
ALTER DATABASE TestForServiceBroker SET TRUSTWORTHY ON;

--Создаем типы сообщений
USE WideWorldImporters
-- For Request
CREATE MESSAGE TYPE
[//WWI/SB/RequestMessage]
VALIDATION=WELL_FORMED_XML; --служит исключительно для проверки, что данные соответствуют типу XML(но можно любой тип)
-- For Reply
CREATE MESSAGE TYPE
[//WWI/SB/ReplyMessage]
VALIDATION=WELL_FORMED_XML; --служит исключительно для проверки, что данные соответствуют типу XML(но можно любой тип)

--Создаем контракт(определяем какие сообщения в рамках этого контракта допустимы)

CREATE CONTRACT [//WWI/SB/Contract]
([//WWI/SB/RequestMessage]
SENT BY INITIATOR,
[//WWI/SB/ReplyMessage]
SENT BY TARGET
);

--Создаем ОЧЕРЕДЬ таргета(настрим позже т.к. через ALTER можно ею рулить еще
CREATE QUEUE TargetQueueWWI;
--и сервис таргета
CREATE SERVICE [//WWI/SB/TargetService]
ON QUEUE TargetQueueWWI
([//WWI/SB/Contract]);

--то же для ИНИЦИАТОРА
CREATE QUEUE InitiatorQueueWWI;

CREATE SERVICE [//WWI/SB/InitiatorService]
ON QUEUE InitiatorQueueWWI
([//WWI/SB/Contract]);


--Создаем процедуры в скрипте CreateProcedure

--1. SendNewInvoice.sql - процедура которая вызывается в процессе какого-то техпроцесса - НЕ АКТИВАЦИОННАЯ для очередей
CREATE PROCEDURE Sales.SendNewInvoice
	@invoiceId INT
AS
BEGIN
	SET NOCOUNT ON;

    --Sending a Request Message to the Target	
	DECLARE @InitDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RequestMessage NVARCHAR(4000);
	
	BEGIN TRAN --на всякий случай в транзакции, т.к. это еще не относится к транзакции ПЕРЕДАЧИ сообщения

	--Формируем XML с корнем RequestMessage где передадим номер инвойса(в принципе сообщение может быть любым)
	SELECT @RequestMessage = (SELECT InvoiceID
							  FROM Sales.Invoices AS Inv
							  WHERE InvoiceID = @invoiceId
							  FOR XML AUTO, root('RequestMessage')); 
	
	
	--Создаем диалог
	BEGIN DIALOG @InitDlgHandle
	FROM SERVICE
	[//WWI/SB/InitiatorService] --от этого сервиса(это сервис текущей БД, поэтому он НЕ строка)
	TO SERVICE
	'//WWI/SB/TargetService'    --к этому сервису(это сервис который может быть где-то, поэтому строка)
	ON CONTRACT
	[//WWI/SB/Contract]         --в рамках этого контракта
	WITH ENCRYPTION=OFF;        --не шифрованный

	--отправляем одно наше подготовленное сообщение, но можно отправить и много сообщений, которые будут обрабатываться строго последовательно)
	SEND ON CONVERSATION @InitDlgHandle 
	MESSAGE TYPE
	[//WWI/SB/RequestMessage]
	(@RequestMessage);
	
	--Это для визуализации - на проде это не нужно
	SELECT @RequestMessage AS SentRequestMessage;
	
	COMMIT TRAN 
END
GO

--2. GetNewInvoice.sql - АКТИВАЦИОННАЯ процедура(всегда без параметров)
CREATE PROCEDURE Sales.GetNewInvoice --будет получать сообщение на таргете
AS
BEGIN

	DECLARE @TargetDlgHandle UNIQUEIDENTIFIER,
			@Message NVARCHAR(4000),
			@MessageType Sysname,
			@ReplyMessage NVARCHAR(4000),
			@ReplyMessageName Sysname,
			@InvoiceID INT,
			@xml XML; 
	
	BEGIN TRAN; 

	--Получаем сообщение от инициатора которое находится у таргета
	RECEIVE TOP(1) --обычно одно сообщение, но можно пачкой
		@TargetDlgHandle = Conversation_Handle, --ИД диалога
		@Message = Message_Body, --само сообщение
		@MessageType = Message_Type_Name --тип сообщения( в зависимости от типа можно по разному обрабатывать) обычно два - запрос и ответ
	FROM dbo.TargetQueueWWI; --имя очереди которую мы ранее создавали

	SELECT @Message; --не для прода

	SET @xml = CAST(@Message AS XML);

	--достали ИД
	SELECT @InvoiceID = R.Iv.value('@InvoiceID','INT') --тут используется язык XPath и он регистрозависимый в отличии от TSQL
	FROM @xml.nodes('/RequestMessage/Inv') as R(Iv);

	IF EXISTS (SELECT * FROM Sales.Invoices WHERE InvoiceID = @InvoiceID)
	BEGIN
		UPDATE Sales.Invoices
		SET InvoiceConfirmedForProcessing = GETUTCDATE() --просто устанавливаем текущую дату в ранее созданном нами поле
		WHERE InvoiceId = @InvoiceID;
	END;
	
	SELECT @Message AS ReceivedRequestMessage, @MessageType; --не для прода
	
	-- Confirm and Send a reply
	IF @MessageType=N'//WWI/SB/RequestMessage' --если наш тип сообщения
	BEGIN
		SET @ReplyMessage =N'<ReplyMessage> Message received</ReplyMessage>'; --ответ
	    --отправляем сообщение нами придуманное, что все прошло хорошо
		SEND ON CONVERSATION @TargetDlgHandle
		MESSAGE TYPE
		[//WWI/SB/ReplyMessage]
		(@ReplyMessage);
		END CONVERSATION @TargetDlgHandle; --А вот и завершение диалога!!! - оно двухстороннее(пока-пока) ЭТО первый ПОКА
		                                   --НЕЛЬЗЯ ЗАВЕРШАТЬ ДИАЛОГ ДО ОТПРАВКИ ПЕРВОГО СООБЩЕНИЯ
	END 
	
	SELECT @ReplyMessage AS SentReplyMessage; --не для прода - это для теста

	COMMIT TRAN;
END

--3. ConfirmInvoice.sql - АКТИВАЦИОННАЯ процедура - обработка сообщения что все прошло хорошо
--ответ на первое ПОКА
CREATE PROCEDURE Sales.ConfirmInvoice
AS
BEGIN
	--Receiving Reply Message from the Target.	
	DECLARE @InitiatorReplyDlgHandle UNIQUEIDENTIFIER,
			@ReplyReceivedMessage NVARCHAR(1000) 
	
	BEGIN TRAN; 

	    --Получаем сообщение от таргета которое находится у инициатора
		RECEIVE TOP(1)
			@InitiatorReplyDlgHandle=Conversation_Handle
			,@ReplyReceivedMessage=Message_Body
		FROM dbo.InitiatorQueueWWI; 
		
		END CONVERSATION @InitiatorReplyDlgHandle; --ЭТО второй ПОКА
		
		SELECT @ReplyReceivedMessage AS ReceivedRepliedMessage; --не для прода

	COMMIT TRAN; 
END


--тепер настроим ОЧЕРЕДЬ или так можем рулить прецессами связанными с очередями
USE [WideWorldImporters]
GO
--пока с MAX_QUEUE_READERS = 0 чтобы вручную вызвать процедуры и увидеть все своими глазами
ALTER QUEUE [dbo].[InitiatorQueueWWI] WITH STATUS = ON --OFF=очередь НЕ доступна(ставим если глобальные проблемы)
,RETENTION = OFF --ON=все завершенные сообщения хранятся в очереди до окончания диалога
,POISON_MESSAGE_HANDLING (STATUS = OFF) --ON=после 5 ошибок очередь будет отключена
,ACTIVATION (STATUS = ON --OFF=очередь не активирует ХП(в PROCEDURE_NAME)(ставим на время исправления ХП, но с потерей сообщений)
,PROCEDURE_NAME = Sales.ConfirmInvoice
,MAX_QUEUE_READERS = 1 --количество потоков(ХП одновременно вызванных) при обработке сообщений(0-32767)
--(0=тоже не позовется процедура)(ставим на время исправления ХП, без потери сообщений)
,EXECUTE AS OWNER --учетка от имени которой запустится ХП
)

GO
ALTER QUEUE [dbo].[TargetQueueWWI] WITH STATUS = ON
,RETENTION = OFF
,POISON_MESSAGE_HANDLING (STATUS = OFF)
,ACTIVATION (STATUS = ON
,PROCEDURE_NAME = Sales.GetNewInvoice
,MAX_QUEUE_READERS = 1
,EXECUTE AS OWNER
)

GO



----
--Начинаем тестировать
----

SELECT InvoiceId, InvoiceConfirmedForProcessing, *
FROM Sales.Invoices
WHERE InvoiceID IN ( 61210,61211,61212,61213) ;

--отправляем конкретный ид в таргет-сервис = на выходе наш select для просмотра
EXEC Sales.SendNewInvoice
@invoiceId = 61210;

--ГДЕ БУДЕТ сообщение в таргете или в инициаторе???

SELECT CAST(message_body AS XML),*
FROM dbo.TargetQueueWWI;

SELECT CAST(message_body AS XML),*
FROM dbo.InitiatorQueueWWI;

--Таргет(получаем сообщение)=вручную запускаем активационные сообщения
EXEC Sales.GetNewInvoice;

--ГДЕ ТЕПЕРЬ БУДЕТ и КАКОЕ сообщение в таргете или в инициаторе???(см. поле message_type_name)

--Initiator(второе пока)
EXEC Sales.ConfirmInvoice;

--список диалогов
SELECT conversation_handle, is_initiator, s.name as 'local service',
far_service, sc.name 'contract', ce.state_desc
FROM sys.conversation_endpoints ce --представление диалогов(постепенно очищается) чтобы ее не переполнять - --НЕЛЬЗЯ ЗАВЕРШАТЬ ДИАЛОГ ДО ОТПРАВКИ ПЕРВОГО СООБЩЕНИЯ
LEFT JOIN sys.services s
ON ce.service_id = s.service_id
LEFT JOIN sys.service_contracts sc
ON ce.service_contract_id = sc.service_contract_id
ORDER BY conversation_handle;

--проставилась текущая дата
SELECT InvoiceId, InvoiceConfirmedForProcessing, *
FROM Sales.Invoices
WHERE InvoiceID IN ( 61210,61211,61212,61213) ;

--Теперь поставим 1 для ридеров(очередь должна вызвать все процедуры автоматом)
ALTER QUEUE [dbo].[InitiatorQueueWWI] WITH STATUS = ON --OFF=очередь НЕ доступна(ставим если глобальные проблемы)
,RETENTION = OFF --ON=все завершенные сообщения хранятся в очереди до окончания диалога
,POISON_MESSAGE_HANDLING (STATUS = OFF) --ON=после 5 ошибок очередь будет отключена
,ACTIVATION (STATUS = ON --OFF=очередь не активирует ХП(в PROCEDURE_NAME)(ставим на время исправления ХП, но с потерей сообщений)
,PROCEDURE_NAME = Sales.ConfirmInvoice
,MAX_QUEUE_READERS = 1 --количество потоков(ХП одновременно вызванных) при обработке сообщений(0-32767)
--(0=тоже не позовется процедура)(ставим на время исправления ХП, без потери сообщений)
,EXECUTE AS OWNER --учетка от имени которой запустится ХП
)

GO
ALTER QUEUE [dbo].[TargetQueueWWI] WITH STATUS = ON
,RETENTION = OFF
,POISON_MESSAGE_HANDLING (STATUS = OFF)
,ACTIVATION (STATUS = ON
,PROCEDURE_NAME = Sales.GetNewInvoice
,MAX_QUEUE_READERS = 1
,EXECUTE AS OWNER
)

GO

--и пошлем сообщение с другим ИД
EXEC Sales.SendNewInvoice
@invoiceId = 61212;

--проверяем
SELECT InvoiceId, InvoiceConfirmedForProcessing, *
FROM Sales.Invoices
WHERE InvoiceID IN ( 61210,61211,61212,61213) ;