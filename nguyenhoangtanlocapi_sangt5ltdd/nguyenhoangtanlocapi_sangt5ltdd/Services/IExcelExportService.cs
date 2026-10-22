using System.Collections.Generic;
using nguyenhoangtanlocapi_sangt5ltdd.Models;

public interface IExcelExportService
{
    byte[] GenerateAttendanceExcel(IEnumerable<AttendanceRecord> records);
}