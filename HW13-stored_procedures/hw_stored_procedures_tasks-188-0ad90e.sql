/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "12 - Хранимые процедуры, функции, триггеры, курсоры".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

USE WideWorldImporters

/*
Во всех заданиях написать хранимую процедуру / функцию и продемонстрировать ее использование.
*/

/*
1) Написать функцию возвращающую Клиента с наибольшей суммой покупки.
*/

create function GetLargestInvoiceCustomerId()
returns int
with execute as caller
as 
begin
	declare @customerId int;

	select @customerId = CustomerID
	from Sales.Invoices
	where InvoiceID in
		(
			select top 1 InvoiceId
			from Sales.InvoiceLines 
			group by InvoiceId
			order by sum(UnitPrice * Quantity) desc
		)

	return @customerId;
end;

declare @customerId int;
exec @customerId = GetLargestInvoiceCustomerId
select @customerId

/*
2) Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
Использовать таблицы :
Sales.Customers
Sales.Invoices
Sales.InvoiceLines
*/

create procedure GetCustomerInvoiceTotalSums @customerId int 
as
begin
	begin transaction;

	if not exists (select 1 from Sales.Customers where CustomerID = @customerId)
	begin
		print N'Клиент не найден. CustomerID = ' + cast(@customerId as nvarchar);
		rollback;
		return;
	end;


	select @customerId as CustomerID, InvoiceID, sum(Quantity * UnitPrice) as TotalSum
	from Sales.InvoiceLines
	where InvoiceID in
		(select InvoiceID from Sales.Invoices where CustomerID = @customerId)
	group by InvoiceId

	commit;
end;

exec GetCustomerInvoiceTotalSums @customerId=2

/*
3) Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему.
*/

create function dbo.AvgTotalSumOfOrder (@CustomerId INT)
returns decimal(18,6)
as
begin
	declare @result decimal(18,6);

	select @result = AVG(UnitPrice*Quantity)
	from Sales.OrderLines ol
	join Sales.Orders o on o.OrderID = ol.OrderID and o.CustomerID = @CustomerId

	return @result;
end;

create procedure dbo.AvgTotalSumOfOrderSP (@CustomerId int)
as
begin
	select AVG(UnitPrice*Quantity)
	from [Sales].[OrderLines] ol
	join [Sales].[Orders] o on o.OrderID = ol.OrderID and o.CustomerID = @CustomerId
end

set statistics time, io on

select dbo.AvgTotalSumOfOrder(103)
exec dbo.AvgTotalSumOfOrderSP 103

/*
4) Создайте табличную функцию покажите как ее можно вызвать для каждой строки result set'а без использования цикла. 
*/

create function dbo.GetOrderedStockItems (@customerId INT)
returns table
as
return
(
	select DISTINCT StockItemName
	from Sales.OrderLines ol
	join Sales.Orders o ON o.OrderID = ol.OrderID 
	join Warehouse.StockItems si ON si.StockItemID = ol.StockItemID
	where CustomerID = @customerId
);

select c.CustomerID,c.CustomerName,f.StockItemName
from Sales.Customers c
cross apply dbo.GetOrderedStockItems(c.CustomerID) f
order by c.CustomerID


/*
5) Опционально. Во всех процедурах укажите какой уровень изоляции транзакций вы бы использовали и почему. 
*/

/*
	В хранимой процедуре GetCustomerInvoiceTotalSums скорее всего стоит поставить уровень изоляции Repeatable Read,
	так как может случиться такая ситуация, в которой проверка на существование клиента с заданным @CustomerID уже прошла успешно,
	но в другой транзакции этот клиент будет удалён. Поэтому запись с данным @CustomerID нужно заблокировать на время выполнения хранимой процедуры.

	Во всех остальных достаточно Read Committed, так как выполняется всего один оператор select.
*/