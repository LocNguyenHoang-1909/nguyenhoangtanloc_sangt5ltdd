using System;
using System.ComponentModel.DataAnnotations;



    public class DailyQrCode
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public string QrCodeToken { get; set; } = string.Empty;

        [Required]
        public DateTime GeneratedDate { get; set; } // Ngày tạo mã (ví dụ: ngày hiện tại)

        [Required]
        public DateTime ExpiryTime { get; set; }    // Thời gian hết hạn (23:59:59 - 12h đêm)
    }
