namespace nguyenhoangtanlocapi_sangt5ltdd.Models
{
    public class AttendanceRecord
    {
        public int Id { get; set; }
        public string UserId { get; set; } = string.Empty;
        
        // Thông tin lần 1 (Đi làm / Check-in)
        public DateTime CheckInTime { get; set; }
        public string Latitude { get; set; } = string.Empty;
        public string Longitude { get; set; } = string.Empty;
        public string Status { get; set; } = "On Time"; // Trạng thái lần 1: "Đi làm đúng giờ", "Đi trễ"

        // Bổ sung thêm thông tin lần 2 (Đi về / Check-out)
        public DateTime? CheckOutTime { get; set; }
        public string? StatusCheckOut { get; set; } // Trạng thái lần 2: "Tan làm sớm", "Tan làm đúng giờ", "Quên chấm công"
    }
}