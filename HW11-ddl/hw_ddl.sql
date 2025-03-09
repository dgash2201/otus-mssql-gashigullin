-- Создание БД "Гостиница"
create database Hotel;

-- Должности
create table Positions
(
	PositionID int primary key identity(1,1),
	Name nvarchar(100) not null unique
);

-- Персонал
create table Staff
(
	EmployeeID int primary key identity(1, 1),
	LastName nvarchar(100) not null,
	FirstName nvarchar(100) not null,
	MiddleName nvarchar(100) null,
	PositionID int null,
	constraint FK_Staff_PositionID_Positions 
		foreign key (PositionID) references dbo.Positions (PositionID)
		on delete set null
);

create nonclustered index Staff_LastName on Staff(LastName);

-- Категории гостиничных номеров
create table RoomCategories
(
	RoomCategoryID int primary key identity(1,1),
	Name nvarchar(100) not null unique,
	Price decimal(15, 2) not null,
	constraint CHK_RoomCategoires_Price_NotNegative check (Price >= 0)
);

-- Гостиничные номера
create table Rooms
(
	RoomID int primary key identity(1,1),
	Floor int not null,
	CategoryID int null,
	MaidEmployeeID int null,
	constraint FK_Rooms_CategoryID_RoomCategories
		foreign key (CategoryID) references RoomCategories(RoomCategoryID)
		on delete set null,
	constraint FK_Rooms_MaidEmployeeID_Staff
		foreign key (MaidEmployeeID) references Staff(EmployeeID)
		on delete set null,
);


