/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "08 - Выборки из XML и JSON полей".

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
Примечания к заданиям 1, 2:
* Если с выгрузкой в файл будут проблемы, то можно сделать просто SELECT c результатом в виде XML. 
* Если у вас в проекте предусмотрен экспорт/импорт в XML, то можете взять свой XML и свои таблицы.
* Если с этим XML вам будет скучно, то можете взять любые открытые данные и импортировать их в таблицы (например, с https://data.gov.ru).
* Пример экспорта/импорта в файл https://docs.microsoft.com/en-us/sql/relational-databases/import-export/examples-of-bulk-import-and-export-of-xml-documents-sql-server
*/


/*
1. В личном кабинете есть файл StockItems.xml.
Это данные из таблицы Warehouse.StockItems.
Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice 

Загрузить эти данные в таблицу Warehouse.StockItems: 
существующие записи в таблице обновить, отсутствующие добавить (сопоставлять записи по полю StockItemName). 

Сделать два варианта: с помощью OPENXML и через XQuery.
*/

-- OpenXML
declare @xml xml;

select @xml = BulkColumn
from openrowset
(bulk 'C:\Test\StockItems.xml', single_clob) as data;

declare @handle int;
exec sp_xml_preparedocument @handle output, @xml;

merge Warehouse.StockItems si
using (
	select * 
	from openxml(@handle, N'/StockItems/Item')
	with
	(
		StockItemName nvarchar(100) '@Name',
		SupplierID int 'SupplierID',
		UnitPackageID int 'Package/UnitPackageID',
		OuterPackageID int 'Package/OuterPackageID',
		QuantityPerOuter int 'Package/QuantityPerOuter',
		TypicalWeightPerUnit decimal(18, 3) 'Package/TypicalWeightPerUnit',
		LeadTimeDays int 'LeadTimeDays', 
		IsChillerStock bit 'IsChillerStock', 
		TaxRate decimal(18, 3) 'TaxRate',
		UnitPrice decimal(18, 2) 'UnitPrice' 
	)
) x (StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice)
on si.StockItemName = x.StockItemName
when matched
	then update
		set si.SupplierID = x.SupplierID,
		UnitPackageID = x.UnitPackageID,
		OuterPackageID = x.OuterPackageID,
		QuantityPerOuter = x.QuantityPerOuter,
		TypicalWeightPerUnit = x.TypicalWeightPerUnit,
		LeadTimeDays = x.LeadTimeDays,
		IsChillerStock = x.IsChillerStock,
		TaxRate = x.TaxRate,
		UnitPrice = x.UnitPrice,
		LastEditedBy = 2
when not matched by target
	then insert (StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice, LastEditedBy)
	values (x.StockItemName, x.SupplierID, x.UnitPackageID, x.OuterPackageID, x.QuantityPerOuter, x.TypicalWeightPerUnit, x.LeadTimeDays, x.IsChillerStock, x.TaxRate, x.UnitPrice, 2);

-- XQuery
declare @xml1 xml;

select @xml1 = BulkColumn
from openrowset
(bulk 'C:\Test\StockItems.xml', single_clob) as data;

merge Warehouse.StockItems si
using (
	select
		Item.value('@Name[1]', 'nvarchar(100)') as StockItemName,
		Item.value('SupplierID[1]', 'int') as SupplierID,
		Item.value('(Package/UnitPackageID)[1]', 'int') as UnitPackageID,
		Item.value('(Package/OuterPackageID)[1]', 'int') as OuterPackageID,
		Item.value('(Package/QuantityPerOuter)[1]', 'int') as QuantityPerOuter,
		Item.value('(Package/TypicalWeightPerUnit)[1]', 'decimal(18, 3)') as TypicalWeightPerUnit,
		Item.value('LeadTimeDays[1]', 'int') as LeadTimeDays, 
		Item.value('IsChillerStock[1]', 'bit') as IsChillerStock, 
		Item.value('TaxRate[1]', 'decimal(18, 3)') as TaxRate,
		Item.value('UnitPrice[1]', 'decimal(18, 2)')  as UnitPrice
	from @xml1.nodes('/StockItems/Item') as t(Item)
) x (StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice)
on si.StockItemName = x.StockItemName
when matched
	then update
		set si.SupplierID = x.SupplierID,
		UnitPackageID = x.UnitPackageID,
		OuterPackageID = x.OuterPackageID,
		QuantityPerOuter = x.QuantityPerOuter,
		TypicalWeightPerUnit = x.TypicalWeightPerUnit,
		LeadTimeDays = x.LeadTimeDays,
		IsChillerStock = x.IsChillerStock,
		TaxRate = x.TaxRate,
		UnitPrice = x.UnitPrice,
		LastEditedBy = 2
when not matched by target
	then insert (StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice, LastEditedBy)
	values (x.StockItemName, x.SupplierID, x.UnitPackageID, x.OuterPackageID, x.QuantityPerOuter, x.TypicalWeightPerUnit, x.LeadTimeDays, x.IsChillerStock, x.TaxRate, x.UnitPrice, 2);


/*
2. Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml
*/


select top 50 
	StockItemName as [@Name],
	SupplierID as [SupplierID],
	UnitPackageID as [Package/UnitPackageID],
	OuterPackageID as [Package/OuterPackageID],
	QuantityPerOuter as [Package/QuantityPerOuter],
	TypicalWeightPerUnit as [Package/TypicalWeightPerUnit],
	LeadTimeDays as [LeadTimeDays], 
	IsChillerStock as [IsChillerStock], 
	TaxRate as [TaxRate],
	UnitPrice as [UnitPrice] 
from Warehouse.StockItems
for xml path('Item'), Root('StockItems')

declare @command nvarchar(max) =
	'bcp "select top 10 CustomerID, CustomerName FROM [WideWorldImporters].[Sales].[Customers] " queryout "C:\Test\StockItems_top50.xml" -w -T -S ' + @@Servername;

/*
3. В таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
Написать SELECT для вывода:
- StockItemID
- StockItemName
- CountryOfManufacture (из CustomFields)
- FirstTag (из поля CustomFields, первое значение из массива Tags)
*/

select StockItemID, StockItemName,
	json_value(CustomFields, N'$.CountryOfManufacture') as CountryOfManufacture,
	json_value(CustomFields, '$.Tags[0]') as FirstTag
from Warehouse.StockItems

/*
4. Найти в StockItems строки, где есть тэг "Vintage".
Вывести: 
- StockItemID
- StockItemName
- (опционально) все теги (из CustomFields) через запятую в одном поле

Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.

Должно быть в таком виде:
... where ... = 'Vintage'

Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%' 
*/


select StockItemID, StockItemName
from Warehouse.StockItems
where exists 
	(
		select 1
		from openjson(json_query(CustomFields, '$.Tags'))
		with ( Tag varchar(100) '$')
		where Tag = 'Vintage'
	)

