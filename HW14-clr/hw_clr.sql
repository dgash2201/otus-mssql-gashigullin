--sp_configure 'clr enabled', 1
--go
--reconfigure
--go
--exec sp_configure 'show advanced options', 1
--go
--reconfigure
--go
--exec sp_configure 'clr strict security', 0
--go
--reconfigure
--go
--exec sp_configure 'show advanced options', 0
--go
--reconfigure
--go

create assembly CLRFunctions from 'C:\Users\Danil\source\repos\otus-mssql-gashigullin\HW14-clr\ClrFunctions.dll' 
go

create function [dbo].GenerateDatesCLR(@strat datetime, @end datetime, @datePart nvarchar(max), @increment int = 1)
returns table (
	value datetime
) 
with execute as caller as
external name CLRFunctions.DateGenerator.GenerateDates



select * from GenerateDatesCLR('2000-07-12', '2001-12-12', 'month', 1)