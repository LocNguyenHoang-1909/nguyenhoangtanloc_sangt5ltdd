using OfficeOpenXml;
using System.Collections.Generic;
using nguyenhoangtanlocapi_sangt5ltdd.Models;

public class ExcelExportService : IExcelExportService
{
    public byte[] GenerateAttendanceExcel(IEnumerable<AttendanceRecord> records)
    {
        // Thiết lập LicenseContext cho EPPlus (Bắt buộc đối với ứng dụng phi thương mại)
        ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

        using var package = new ExcelPackage();
        var worksheet = package.Workbook.Worksheets.Add("BaoCaoChamCong");

        // Tạo dòng tiêu đề (Header) cho bảng báo cáo
        worksheet.Cells[1, 1].Value = "ID";
        worksheet.Cells[1, 2].Value = "User ID";
        worksheet.Cells[1, 3].Value = "Thời gian chấm công";
        worksheet.Cells[1, 4].Value = "Vĩ độ (Latitude)";
        worksheet.Cells[1, 5].Value = "Kinh độ (Longitude)";
        worksheet.Cells[1, 6].Value = "Trạng thái";

        // Định dạng in đậm cho dòng tiêu đề
        using (var range = worksheet.Cells[1, 1, 1, 6])
        {
            range.Style.Font.Bold = true;
        }

        // Đổ dữ liệu từ danh sách records vào các dòng tiếp theo
        int row = 2;
        foreach (var item in records)
        {
            worksheet.Cells[row, 1].Value = item.Id;
            worksheet.Cells[row, 2].Value = item.UserId;
            worksheet.Cells[row, 3].Value = item.CheckInTime.ToString("yyyy-MM-dd HH:mm:ss");
            worksheet.Cells[row, 4].Value = item.Latitude;
            worksheet.Cells[row, 5].Value = item.Longitude;
            worksheet.Cells[row, 6].Value = item.Status;
            row++;
        }

        // Tự động căn chỉnh độ rộng các cột cho vừa vặn nội dung
        worksheet.Cells[worksheet.Dimension.Address].AutoFitColumns();

        // Trả về file dưới dạng mảng byte để Controller gửi về cho client tải xuống
        return package.GetAsByteArray();
    }
}