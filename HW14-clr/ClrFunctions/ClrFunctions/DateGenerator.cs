using Microsoft.SqlServer.Server;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlTypes;
using System.Linq;

public class DateGenerator
{
    [SqlFunction(FillRowMethodName = "GenerateDatesFillRow",
        TableDefinition = "Value datetime",
        DataAccess = DataAccessKind.None)]
    static public IEnumerator GenerateDates(SqlDateTime start, SqlDateTime end, string datePart, int increment = 1)
    {
        var current = start.Value;
        var part = datePart.Trim().ToLowerInvariant();
        var allowedParts = new[] { "day", "month", "year" };

        if (allowedParts.All(p => p != part))
            throw new ArgumentException("Недопустимое значение части даты. Используйте: year, month, day.");

        if (increment <= 0)
            throw new ArgumentException("Значение инкремента должно быть больше 0.");

        while (current < end.Value)
        {
            yield return current;

            if (part == "day")
            {
                current = current.AddDays(increment);
            }

            if (part == "month")
            {
                current = current.AddMonths(increment);
            }

            if (part == "year")
            {
                current = current.AddYears(increment);
            }
        }

        yield break;
    }

    public static void GenerateDatesFillRow(object value, out SqlDateTime result)
    {
        var dateTime = (DateTime)value;
        result = new SqlDateTime(dateTime.Date);
    }
}