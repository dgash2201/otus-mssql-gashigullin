USE [WideWorldImporters];

--�������� �������������� ������� ��� ����������� ���������� ������ �������
ALTER TABLE Sales.Invoices
ADD InvoiceConfirmedForProcessing DATETIME;

USE [WideWorldImporters];
Select * FROM Sales.Invoices

--Service Broker ������� ��?
select name, is_broker_enabled
from sys.databases;

--�������� ������
USE master
ALTER DATABASE TestForServiceBroker
SET ENABLE_BROKER WITH ROLLBACK IMMEDIATE; --NO WAIT --prod (� �������������������� ������!!! �� ����� ��� �� �����)

--�� ������ ��������������� �� ����� ����������� ������!!!
ALTER AUTHORIZATION
ON DATABASE::WideWorldImporters TO [ServiceBrokerUser];

ALTER AUTHORIZATION
ON DATABASE::TestForServiceBroker TO [ServiceBrokerUser];

--�������� ��� ����� �������� �������� ��� ������������� ������������ ����� �������� ����� ����������
--�� � ����������(���������� ������� �������, ��� ���� �� ����� ��������)
--���� �� �������� �� � ����� �� ���������, �� ��� �������� ��������� � OFF
ALTER DATABASE WideWorldImporters SET TRUSTWORTHY ON;
ALTER DATABASE TestForServiceBroker SET TRUSTWORTHY ON;

--������� ���� ���������
USE WideWorldImporters
-- For Request
CREATE MESSAGE TYPE
[//WWI/SB/RequestMessage]
VALIDATION=WELL_FORMED_XML; --������ ������������� ��� ��������, ��� ������ ������������� ���� XML(�� ����� ����� ���)
-- For Reply
CREATE MESSAGE TYPE
[//WWI/SB/ReplyMessage]
VALIDATION=WELL_FORMED_XML; --������ ������������� ��� ��������, ��� ������ ������������� ���� XML(�� ����� ����� ���)

--������� ��������(���������� ����� ��������� � ������ ����� ��������� ���������)

CREATE CONTRACT [//WWI/SB/Contract]
([//WWI/SB/RequestMessage]
SENT BY INITIATOR,
[//WWI/SB/ReplyMessage]
SENT BY TARGET
);

--������� ������� �������(������� ����� �.�. ����� ALTER ����� �� ������ ���
CREATE QUEUE TargetQueueWWI;
--� ������ �������
CREATE SERVICE [//WWI/SB/TargetService]
ON QUEUE TargetQueueWWI
([//WWI/SB/Contract]);

--�� �� ��� ����������
CREATE QUEUE InitiatorQueueWWI;

CREATE SERVICE [//WWI/SB/InitiatorService]
ON QUEUE InitiatorQueueWWI
([//WWI/SB/Contract]);


--������� ��������� � ������� CreateProcedure

--1. SendNewInvoice.sql - ��������� ������� ���������� � �������� ������-�� ����������� - �� ������������� ��� ��������
CREATE PROCEDURE Sales.SendNewInvoice
	@invoiceId INT
AS
BEGIN
	SET NOCOUNT ON;

    --Sending a Request Message to the Target	
	DECLARE @InitDlgHandle UNIQUEIDENTIFIER;
	DECLARE @RequestMessage NVARCHAR(4000);
	
	BEGIN TRAN --�� ������ ������ � ����������, �.�. ��� ��� �� ��������� � ���������� �������� ���������

	--��������� XML � ������ RequestMessage ��� ��������� ����� �������(� �������� ��������� ����� ���� �����)
	SELECT @RequestMessage = (SELECT InvoiceID
							  FROM Sales.Invoices AS Inv
							  WHERE InvoiceID = @invoiceId
							  FOR XML AUTO, root('RequestMessage')); 
	
	
	--������� ������
	BEGIN DIALOG @InitDlgHandle
	FROM SERVICE
	[//WWI/SB/InitiatorService] --�� ����� �������(��� ������ ������� ��, ������� �� �� ������)
	TO SERVICE
	'//WWI/SB/TargetService'    --� ����� �������(��� ������ ������� ����� ���� ���-��, ������� ������)
	ON CONTRACT
	[//WWI/SB/Contract]         --� ������ ����� ���������
	WITH ENCRYPTION=OFF;        --�� �����������

	--���������� ���� ���� �������������� ���������, �� ����� ��������� � ����� ���������, ������� ����� �������������� ������ ���������������)
	SEND ON CONVERSATION @InitDlgHandle 
	MESSAGE TYPE
	[//WWI/SB/RequestMessage]
	(@RequestMessage);
	
	--��� ��� ������������ - �� ����� ��� �� �����
	SELECT @RequestMessage AS SentRequestMessage;
	
	COMMIT TRAN 
END
GO

--2. GetNewInvoice.sql - ������������� ���������(������ ��� ����������)
CREATE PROCEDURE Sales.GetNewInvoice --����� �������� ��������� �� �������
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

	--�������� ��������� �� ���������� ������� ��������� � �������
	RECEIVE TOP(1) --������ ���� ���������, �� ����� ������
		@TargetDlgHandle = Conversation_Handle, --�� �������
		@Message = Message_Body, --���� ���������
		@MessageType = Message_Type_Name --��� ���������( � ����������� �� ���� ����� �� ������� ������������) ������ ��� - ������ � �����
	FROM dbo.TargetQueueWWI; --��� ������� ������� �� ����� ���������

	SELECT @Message; --�� ��� �����

	SET @xml = CAST(@Message AS XML);

	--������� ��
	SELECT @InvoiceID = R.Iv.value('@InvoiceID','INT') --��� ������������ ���� XPath � �� ����������������� � ������� �� TSQL
	FROM @xml.nodes('/RequestMessage/Inv') as R(Iv);

	IF EXISTS (SELECT * FROM Sales.Invoices WHERE InvoiceID = @InvoiceID)
	BEGIN
		UPDATE Sales.Invoices
		SET InvoiceConfirmedForProcessing = GETUTCDATE() --������ ������������� ������� ���� � ����� ��������� ���� ����
		WHERE InvoiceId = @InvoiceID;
	END;
	
	SELECT @Message AS ReceivedRequestMessage, @MessageType; --�� ��� �����
	
	-- Confirm and Send a reply
	IF @MessageType=N'//WWI/SB/RequestMessage' --���� ��� ��� ���������
	BEGIN
		SET @ReplyMessage =N'<ReplyMessage> Message received</ReplyMessage>'; --�����
	    --���������� ��������� ���� �����������, ��� ��� ������ ������
		SEND ON CONVERSATION @TargetDlgHandle
		MESSAGE TYPE
		[//WWI/SB/ReplyMessage]
		(@ReplyMessage);
		END CONVERSATION @TargetDlgHandle; --� ��� � ���������� �������!!! - ��� �������������(����-����) ��� ������ ����
		                                   --������ ��������� ������ �� �������� ������� ���������
	END 
	
	SELECT @ReplyMessage AS SentReplyMessage; --�� ��� ����� - ��� ��� �����

	COMMIT TRAN;
END

--3. ConfirmInvoice.sql - ������������� ��������� - ��������� ��������� ��� ��� ������ ������
--����� �� ������ ����
CREATE PROCEDURE Sales.ConfirmInvoice
AS
BEGIN
	--Receiving Reply Message from the Target.	
	DECLARE @InitiatorReplyDlgHandle UNIQUEIDENTIFIER,
			@ReplyReceivedMessage NVARCHAR(1000) 
	
	BEGIN TRAN; 

	    --�������� ��������� �� ������� ������� ��������� � ����������
		RECEIVE TOP(1)
			@InitiatorReplyDlgHandle=Conversation_Handle
			,@ReplyReceivedMessage=Message_Body
		FROM dbo.InitiatorQueueWWI; 
		
		END CONVERSATION @InitiatorReplyDlgHandle; --��� ������ ����
		
		SELECT @ReplyReceivedMessage AS ReceivedRepliedMessage; --�� ��� �����

	COMMIT TRAN; 
END


--����� �������� ������� ��� ��� ����� ������ ���������� ���������� � ���������
USE [WideWorldImporters]
GO
--���� � MAX_QUEUE_READERS = 0 ����� ������� ������� ��������� � ������� ��� ������ �������
ALTER QUEUE [dbo].[InitiatorQueueWWI] WITH STATUS = ON --OFF=������� �� ��������(������ ���� ���������� ��������)
,RETENTION = OFF --ON=��� ����������� ��������� �������� � ������� �� ��������� �������
,POISON_MESSAGE_HANDLING (STATUS = OFF) --ON=����� 5 ������ ������� ����� ���������
,ACTIVATION (STATUS = ON --OFF=������� �� ���������� ��(� PROCEDURE_NAME)(������ �� ����� ����������� ��, �� � ������� ���������)
,PROCEDURE_NAME = Sales.ConfirmInvoice
,MAX_QUEUE_READERS = 1 --���������� �������(�� ������������ ���������) ��� ��������� ���������(0-32767)
--(0=���� �� ��������� ���������)(������ �� ����� ����������� ��, ��� ������ ���������)
,EXECUTE AS OWNER --������ �� ����� ������� ���������� ��
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
--�������� �����������
----

SELECT InvoiceId, InvoiceConfirmedForProcessing, *
FROM Sales.Invoices
WHERE InvoiceID IN ( 61210,61211,61212,61213) ;

--���������� ���������� �� � ������-������ = �� ������ ��� select ��� ���������
EXEC Sales.SendNewInvoice
@invoiceId = 61210;

--��� ����� ��������� � ������� ��� � ����������???

SELECT CAST(message_body AS XML),*
FROM dbo.TargetQueueWWI;

SELECT CAST(message_body AS XML),*
FROM dbo.InitiatorQueueWWI;

--������(�������� ���������)=������� ��������� ������������� ���������
EXEC Sales.GetNewInvoice;

--��� ������ ����� � ����� ��������� � ������� ��� � ����������???(��. ���� message_type_name)

--Initiator(������ ����)
EXEC Sales.ConfirmInvoice;

--������ ��������
SELECT conversation_handle, is_initiator, s.name as 'local service',
far_service, sc.name 'contract', ce.state_desc
FROM sys.conversation_endpoints ce --������������� ��������(���������� ���������) ����� �� �� ����������� - --������ ��������� ������ �� �������� ������� ���������
LEFT JOIN sys.services s
ON ce.service_id = s.service_id
LEFT JOIN sys.service_contracts sc
ON ce.service_contract_id = sc.service_contract_id
ORDER BY conversation_handle;

--������������ ������� ����
SELECT InvoiceId, InvoiceConfirmedForProcessing, *
FROM Sales.Invoices
WHERE InvoiceID IN ( 61210,61211,61212,61213) ;

--������ �������� 1 ��� �������(������� ������ ������� ��� ��������� ���������)
ALTER QUEUE [dbo].[InitiatorQueueWWI] WITH STATUS = ON --OFF=������� �� ��������(������ ���� ���������� ��������)
,RETENTION = OFF --ON=��� ����������� ��������� �������� � ������� �� ��������� �������
,POISON_MESSAGE_HANDLING (STATUS = OFF) --ON=����� 5 ������ ������� ����� ���������
,ACTIVATION (STATUS = ON --OFF=������� �� ���������� ��(� PROCEDURE_NAME)(������ �� ����� ����������� ��, �� � ������� ���������)
,PROCEDURE_NAME = Sales.ConfirmInvoice
,MAX_QUEUE_READERS = 1 --���������� �������(�� ������������ ���������) ��� ��������� ���������(0-32767)
--(0=���� �� ��������� ���������)(������ �� ����� ����������� ��, ��� ������ ���������)
,EXECUTE AS OWNER --������ �� ����� ������� ���������� ��
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

--� ������ ��������� � ������ ��
EXEC Sales.SendNewInvoice
@invoiceId = 61212;

--���������
SELECT InvoiceId, InvoiceConfirmedForProcessing, *
FROM Sales.Invoices
WHERE InvoiceID IN ( 61210,61211,61212,61213) ;