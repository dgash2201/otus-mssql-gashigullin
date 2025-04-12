use WideWorldImporters

alter database WideWorldImporters add filegroup CT_2013
alter database WideWorldImporters add filegroup CT_2014
alter database WideWorldImporters add filegroup CT_2015
alter database WideWorldImporters add filegroup CT_2016
alter database WideWorldImporters add filegroup CT_2017
go

alter database WideWorldImporters add file (name = 'ct2013', filename = 'C:\Test\ct2013.ndf') to filegroup CT_2013
alter database WideWorldImporters add file (name = 'ct2014', filename = 'C:\Test\ct2014.ndf') to filegroup CT_2014
alter database WideWorldImporters add file (name = 'ct2015', filename = 'C:\Test\ct2015.ndf') to filegroup CT_2015
alter database WideWorldImporters add file (name = 'ct2016', filename = 'C:\Test\ct2016.ndf') to filegroup CT_2016
alter database WideWorldImporters add file (name = 'ct2017', filename = 'C:\Test\ct2017.ndf') to filegroup CT_2017
go

create partition function pf_dt(date)
as
	range right for values ('2014-01-01','2015-01-01','2016-01-01', '2017-01-01')
go


create partition scheme ps_dt
as
	partition pf_dt to (CT_2013,CT_2014,CT_2015,CT_2016, CT_2017)
go

create clustered index CX_Sales_CustomerTransactions
	on Sales.CustomerTransactions(TransactionDate) with (drop_existing = on)
	on ps_dt(TransactionDate);
go


select $partition.pf_dt(TransactionDate) as section, min(TransactionDate) as MinTransactionDate, max(TransactionDate) as MaxTransactionDate,
    count(*) as Count, fg.name as FileGroupName
from Sales.CustomerTransactions
join sys.partitions p on $partition.pf_dt(TransactionDate) = p.partition_number
join sys.destination_data_spaces dds on p.partition_number = dds.destination_id
join sys.filegroups fg on dds.data_space_id = fg.data_space_id
where p.object_id = object_id('Sales.CustomerTransactions') -- указываем имя таблицы
group by $partition.pf_dt(TransactionDate), fg.name
order by section
