-- ������ ��� ��������� ������ ���������� �� �������
create nonclustered index Staff_LastName on Staff(LastName);

-- ������ ��� ��������� ������ ������������ �� ���� ������ ������������
create nonclustered index Bookings_StartDate on Bookings(StartDate);

-- ������ ��� ��������� ������ ������������ �� ���� ����� ������������
create nonclustered index Bookings_EndDate on Bookings(EndDate);

-- ������ ��� ��������� ������ ����� �� �������
create nonclustered index Guests_LastName on Guests(LastName);

-- ������ ��� ��������� ������ ����� �� ������ ���������
create nonclustered index Guests_DocumentNumber on Guests(DocumentNumber);