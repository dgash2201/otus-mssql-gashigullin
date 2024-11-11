/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, JOIN".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД WideWorldImporters можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.
*/

select StockItemID, StockItemName
from Warehouse.StockItems si
where si.StockItemName like '%urgent%' or si.StockItemName like 'Animal%'

/*
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно.
*/

select s.SupplierID, s.SupplierName
from Purchasing.Suppliers s
left join Purchasing.PurchaseOrders po on s.SupplierID = po.SupplierID
where po.PurchaseOrderID is null

/*
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей.

Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).

Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.
*/

select o.OrderID,
	FORMAT(o.OrderDate, 'D', 'ru-ru') as OrderDate,
	FORMAT(o.OrderDate, 'MMMM', 'ru-ru') as [Месяц],
	datepart(quarter, o.OrderDate) as [Квартал],
	((datepart(month, o.OrderDate) - 1) / 4) + 1 as [Треть года],
	c.CustomerName
from Sales.Orders o
join Sales.Customers c on o.CustomerID = c.CustomerID
join Sales.OrderLines ol on o.OrderID = ol.OrderID
where (ol.UnitPrice > 100 or ol.Quantity > 20) and o.PickingCompletedWhen is not null
order by [Квартал], [Треть года], OrderDate

-- с постраничной выборкой
select o.OrderID,
	FORMAT(o.OrderDate, 'D', 'ru-ru') as OrderDate,
	FORMAT(o.OrderDate, 'MMMM', 'ru-ru') as [Месяц],
	datepart(quarter, o.OrderDate) as [Квартал],
	((datepart(month, o.OrderDate) - 1) / 4) + 1 as [Треть года],
	c.CustomerName
from Sales.Orders o
join Sales.Customers c on o.CustomerID = c.CustomerID
join Sales.OrderLines ol on o.OrderID = ol.OrderID
where (ol.UnitPrice > 100 or ol.Quantity > 20) and o.PickingCompletedWhen is not null
order by [Квартал], [Треть года], OrderDate offset 1000 rows
fetch next 100 rows only

/*
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)

Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People.
*/

select dm.DeliveryMethodName,
	po.ExpectedDeliveryDate,
	s.SupplierName,
	p.FullName as ContactPerson
from Purchasing.Suppliers s
join Purchasing.PurchaseOrders po on s.SupplierID = po.SupplierID
join Application.DeliveryMethods dm on po.DeliveryMethodID = dm.DeliveryMethodID
join Application.People p on s.PrimaryContactPersonID = p.PersonID
where po.ExpectedDeliveryDate between '2013-01-01' and '2013-01-31'
	and (dm.DeliveryMethodName = 'Air Freight' or dm.DeliveryMethodName = 'Refrigerated Air Freight')
	and po.IsOrderFinalized = 1

/*
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.
*/

select top 10 o.OrderID,
	o.OrderDate,
	c.CustomerName,
	p.FullName as [Имя сотрудника]
from Sales.Orders o
join Sales.Customers c on o.CustomerID = c.CustomerID
join Application.People p on o.SalespersonPersonID = p.PersonID
order by o.OrderDate desc

/*
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.
*/

select c.CustomerId,
	c.CustomerName,
	c.PhoneNumber
from Sales.Customers c
join Sales.Orders o on o.CustomerID = c.CustomerID
join Sales.OrderLines ol on ol.OrderID = o.OrderID
join Warehouse.StockItems si on si.StockItemID = ol.StockItemID
where si.StockItemName = 'Chocolate frogs 250g'
