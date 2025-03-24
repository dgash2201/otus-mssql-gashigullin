-- Индекс для ускорения поиска сотрудника по фамилии
create nonclustered index Staff_LastName on Staff(LastName);

-- Индекс для ускорения поиска бронирования по дате начала бронирования
create nonclustered index Bookings_StartDate on Bookings(StartDate);

-- Индекс для ускорения поиска бронирования по дате конца бронирования
create nonclustered index Bookings_EndDate on Bookings(EndDate);

-- Индекс для ускорения поиска гостя по фамилии
create nonclustered index Guests_LastName on Guests(LastName);

-- Индекс для ускорения поиска гостя по номеру документа
create nonclustered index Guests_DocumentNumber on Guests(DocumentNumber);