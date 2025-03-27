/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

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
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/

select i.InvoiceID,
	i.CustomerID,
	i.InvoiceDate,
	eomonth(i.InvoiceDate),
	(select sum(Quantity * UnitPrice) from Sales.InvoiceLines where InvoiceID = i.InvoiceID) as [Сумма продажи],
	(
		select sum(InvoiceLines.Quantity * InvoiceLines.UnitPrice)
		from Sales.Invoices
		join Sales.InvoiceLines on Invoices.InvoiceID = InvoiceLines.InvoiceID
		where InvoiceDate <= eomonth(i.InvoiceDate)
	) as [Нарастающий итог по месяцу]
from Sales.Invoices i
join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
order by i.InvoiceDate, i.InvoiceID

/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/

select i.InvoiceID,
	i.CustomerID,
	i.InvoiceDate,
	sum(il.Quantity * il.UnitPrice) over (partition by i.InvoiceID) as InvoiceSum,
	sum(il.Quantity * il.UnitPrice) over (order by eomonth(i.InvoiceDate)) as [Нарастающий итог по месяцу]
from Sales.Invoices i
join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
order by i.InvoiceDate, i.InvoiceID

/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

;with TotalCounts as
(
	select distinct
		il.StockItemID,
		month(i.InvoiceDate) as Month,
		sum(il.Quantity) over (partition by month(i.InvoiceDate), il.StockItemID) as TotalCount
	from Sales.Invoices i
	join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
	where i.InvoiceDate between '2016-01-01' and '2016-12-31'
),
R as
(
	select
		StockItemId,
		Month,
		row_number() over (partition by Month order by TotalCount) as rn
	from TotalCounts c
)
select
	Month,
	rn as [Место по популярности],
	R.StockItemID,
	si.StockItemName
from R
join Warehouse.StockItems si on R.StockItemID = si.StockItemID
where rn <= 2
order by Month, rn

/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/

select
	si.StockItemName,
	row_number() over (partition by substring(si.StockItemName, 1, 1) order by si.StockItemName),
	count(*) over () as [Общее количество товаров],
	count(*) over (partition by substring(si.StockItemName, 1, 1)) as [Количество товаров по первой букве названия],
	lead(si.StockItemID) over (order by si.StockItemName) as [Следующий ID],
	lag(si.StockItemID) over (order by si.StockItemName) as [Предыдущий ID],
	lag(si.StockItemName, 2, 'No items') over (order by si.StockItemName) as [Название товара 2 строки назад],
	ntile(30) over (order by si.TypicalWeightPerUnit) as [Номер группы]
from 
WareHouse.StockItems si
order by si.StockItemName

/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/

;with LastSalespersonInvoices as
(
	select distinct
		SalespersonPersonID,
		last_value(InvoiceID) over (partition by SalespersonPersonID order by InvoiceDate range between current row and unbounded following) as InvoiceID,
		last_value(InvoiceDate) over (partition by SalespersonPersonID order by InvoiceDate range between current row and unbounded following) as InvoiceDate,
		last_value(CustomerID) over (partition by SalespersonPersonID order by InvoiceDate range between current row and unbounded following) as CustomerID
	from Sales.Invoices
)
select distinct
	SalespersonPersonID,
	p.FullName as SalespersonName,
	lsi.CustomerID,
	c.CustomerName,
	InvoiceDate,
	sum(il.Quantity * il.UnitPrice) over (partition by lsi.InvoiceID) as [Сумма сделки]
from LastSalespersonInvoices lsi
join Application.People p on lsi.SalespersonPersonID = p.PersonID
join Sales.Customers c on lsi.CustomerID = c.CustomerID
join Sales.InvoiceLines il on lsi.InvoiceID = il.InvoiceID
order by SalespersonPersonID


/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

;with StockItemsTop as
(
  select distinct
    i.CustomerID,
    c.CustomerName,
    il.StockItemID,
    il.UnitPrice,
    max(i.InvoiceDate) over (partition by i.CustomerID, il.StockItemId) as InvoiceDate,
    dense_rank() over (partition by i.CustomerID order by il.UnitPrice) as rn
  from Sales.Invoices i
  join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
  join Sales.Customers c on i.CustomerID = c.CustomerID
)
select
  CustomerID,
  CustomerName,
  StockItemID,
  UnitPrice,
  InvoiceDate
from StockItemsTop
where rn <= 2
order by CustomerID, UnitPrice


--Опционально можете для каждого запроса без оконных функций сделать вариант запросов с оконными функциями и сравнить их производительность. 