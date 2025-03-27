/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers 
*/

declare @i int = 0

while @i < 5 
begin
	insert into Sales.Customers
           (CustomerID
           ,CustomerName
           ,BillToCustomerID
           ,CustomerCategoryID
           ,BuyingGroupID
           ,PrimaryContactPersonID
           ,AlternateContactPersonID
           ,DeliveryMethodID
           ,DeliveryCityID
           ,PostalCityID
           ,AccountOpenedDate
           ,StandardDiscountPercentage
           ,IsStatementSent
           ,IsOnCreditHold
           ,PaymentDays
           ,PhoneNumber
           ,FaxNumber
           ,WebsiteURL
           ,DeliveryAddressLine1
           ,DeliveryAddressLine2
           ,DeliveryPostalCode
           ,PostalAddressLine1
           ,PostalAddressLine2
           ,PostalPostalCode
           ,LastEditedBy)
	values
    (
		next value for Sequences.CustomerID
		,'New' + CAST(@i as nvarchar)
		,1
		,3
		,1
		,1001
		,1002
		,3
		,19586
		,19586
		,'2014-03-01'
		,0.000
		,0
		,0
		,7
		,'(308) 555-0100'
		,'(308) 555-0101'
		,'http://www.tailspintoys.com'
		,'Shop 67'
		,'1877 Mittal Road'
		,'90410'
		,'PO Box 8975'
		,'Ribeiroville'
		,'90410'
		,1
	);

	set @i += 1
end

/*
2. Удалите одну запись из Customers, которая была вами добавлена
*/

delete from Sales.Customers
where CustomerName = 'New1'


/*
3. Изменить одну запись, из добавленных через UPDATE
*/

update Sales.Customers
set CustomerName = 'New82'
where CustomerName = 'New2'

/*
4. Написать MERGE, который вставит вставит запись в клиенты, если ее там нет, и изменит если она уже есть
*/

merge Sales.Customers c
using (select 'New Customer 80' as CustomerName
		,1 as BillToCustomerID
		,3 as CustomerCategoryID
		,1 as BuyingGroupID
		,1001 as PrimaryContactPersonID
		,1002 as AlternateContactPersonID
		,3 as DeliveryMethodID
		,19586 as DeliveryCityID
		,19586 as PostalCityID
		,'2014-03-01' as AccountOpenedDate
		,0.000 as StandardDiscountPercentage
		,0 as IsStatementSent
		,0 as IsOnCreditHold
		,7 as PaymentDays
		,'(308) 555-0100' as PhoneNumber
		,'(308) 555-0101' as FaxNumber
		,'http://www.tailspintoys.com' as WebsiteURL
		,'Shop 67' as DeliveryAddressLine1
		,'1877 Mittal Road' as DeliveryAddressLine2
		,'90410'  as DeliveryPostalCode
		,'PO Box 8975' as PostalAddressLine1
		,'Ribeiroville' as PostalAddressLine2
		,'90410' as PostalPostalCode
		,1 as LastEditedBy
	) as t
on c.CustomerName = t.CustomerName
when matched
	then update set 
		c.BillToCustomerID = t.BillToCustomerID,
        c.CustomerCategoryID = t.CustomerCategoryID,
        c.BuyingGroupID = t.BuyingGroupID,
        c.PrimaryContactPersonID = t.PrimaryContactPersonID,
        c.AlternateContactPersonID = t.AlternateContactPersonID,
        c.DeliveryMethodID = t.DeliveryMethodID,
        c.DeliveryCityID = t.DeliveryCityID,
        c.PostalCityID = t.PostalCityID,
        c.AccountOpenedDate = t.AccountOpenedDate,
        c.StandardDiscountPercentage = t.StandardDiscountPercentage,
        c.IsStatementSent = t.IsStatementSent,
        c.IsOnCreditHold = t.IsOnCreditHold,
        c.PaymentDays = t.PaymentDays,
        c.PhoneNumber = t.PhoneNumber,
        c.FaxNumber = t.FaxNumber,
        c.WebsiteURL = t.WebsiteURL,
        c.DeliveryAddressLine1 = t.DeliveryAddressLine1,
        c.DeliveryAddressLine2 = t.DeliveryAddressLine2,
        c.DeliveryPostalCode = t.DeliveryPostalCode,
        c.PostalAddressLine1 = t.PostalAddressLine1,
        c.PostalAddressLine2 = t.PostalAddressLine2,
        c.PostalPostalCode = t.PostalPostalCode,
        c.LastEditedBy = t.LastEditedBy
when not matched
	then insert (CustomerID
        ,CustomerName
        ,BillToCustomerID
        ,CustomerCategoryID
        ,BuyingGroupID
        ,PrimaryContactPersonID
        ,AlternateContactPersonID
        ,DeliveryMethodID
        ,DeliveryCityID
        ,PostalCityID
        ,AccountOpenedDate
        ,StandardDiscountPercentage
        ,IsStatementSent
        ,IsOnCreditHold
        ,PaymentDays
        ,PhoneNumber
        ,FaxNumber
        ,WebsiteURL
        ,DeliveryAddressLine1
        ,DeliveryAddressLine2
        ,DeliveryPostalCode
        ,PostalAddressLine1
        ,PostalAddressLine2
        ,PostalPostalCode
        ,LastEditedBy)
	values (default
        ,t.CustomerName
        ,t.BillToCustomerID
        ,t.CustomerCategoryID
        ,t.BuyingGroupID
        ,t.PrimaryContactPersonID
        ,t.AlternateContactPersonID
        ,t.DeliveryMethodID
        ,t.DeliveryCityID
        ,t.PostalCityID
        ,t.AccountOpenedDate
        ,t.StandardDiscountPercentage
        ,t.IsStatementSent
        ,t.IsOnCreditHold
        ,t.PaymentDays
        ,t.PhoneNumber
        ,t.FaxNumber
        ,t.WebsiteURL
        ,t.DeliveryAddressLine1
        ,t.DeliveryAddressLine2
        ,t.DeliveryPostalCode
        ,t.PostalAddressLine1
        ,t.PostalAddressLine2
        ,t.PostalPostalCode
        ,t.LastEditedBy)
output $action, inserted.*, deleted.*;

/*
5. Напишите запрос, который выгрузит данные через bcp out и загрузить через bulk insert
*/

declare @sql VARCHAR(8000);
select @sql = 'bcp "select top 10 CustomerID, CustomerName FROM [WideWorldImporters].[Sales].[Customers] " queryout "C:\Test\Test.txt" -c -t, -T  -S ' + @@Servername;

exec master..xp_cmdshell @sql;

--Создаём пустую временную таблицу
drop table if exists #CustomersInfo;
select CustomerID, CustomerName INTO #CustomersInfo
from Sales.Customers
where 1 != 1

select * from #CustomersInfo

bulk insert #CustomersInfo
    from "C:\Test\Test.txt"
	with 
		(
		batchsize = 100,
		datafiletype = 'char',
		fieldterminator = ',',
		rowterminator ='\n',
		keepnulls,
		tablock
		);

select * from #CustomersInfo


--USE master;
--GO

--EXECUTE sp_configure 'show advanced options', 1;
--GO

--RECONFIGURE;
--GO

--EXECUTE sp_configure 'xp_cmdshell', 1;
--GO

--RECONFIGURE;
--GO

--EXECUTE sp_configure 'show advanced options', 0;
--GO

--RECONFIGURE;
--GO