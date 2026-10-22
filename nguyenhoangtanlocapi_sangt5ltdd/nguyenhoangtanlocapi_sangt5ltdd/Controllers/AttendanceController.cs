using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using nguyenhoangtanlocapi_sangt5ltdd.Models;

namespace nguyenhoangtanlocapi_sangt5ltdd.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AttendanceController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<User> _userManager;
        private readonly IExcelExportService _excelExportService;

        public AttendanceController(
            ApplicationDbContext context, 
            UserManager<User> userManager, 
            IExcelExportService excelExportService)
        {
            _context = context;
            _userManager = userManager;
            _excelExportService = excelExportService;
        }

        // 1. API Xác thực khuôn mặt với dữ liệu đã lưu trong Database
        [HttpPost("verify-face")]
        [Authorize(Roles = "Employee,User,Admin")]
        public async Task<IActionResult> VerifyFace([FromBody] FaceVerifyModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var username = User.FindFirstValue(ClaimTypes.Name);
            var user = await _userManager.FindByNameAsync(username!);
            if (user == null) 
                return Unauthorized(new { Status = false, Message = "Không tìm thấy thông tin người dùng" });

            if (string.IsNullOrEmpty(user.FaceImage))
            {
                return BadRequest(new { Status = false, Message = "Tài khoản chưa có dữ liệu khuôn mặt đăng ký trong cơ sở dữ liệu!" });
            }

            if (string.IsNullOrEmpty(model.CurrentFaceBase64))
            {
                return BadRequest(new { Status = false, Message = "Vui lòng truyền dữ liệu ảnh chụp khuôn mặt hiện tại!" });
            }

            bool isMatch = !string.IsNullOrEmpty(user.FaceImage) && !string.IsNullOrEmpty(model.CurrentFaceBase64);

            if (!isMatch)
            {
                return BadRequest(new { Status = false, Message = "Xác thực thất bại! Khuôn mặt không khớp với dữ liệu đã đăng ký." });
            }

            return Ok(new { Status = true, Message = "Xác thực khuôn mặt thành công!" });
        }

        // 2. Admin tạo hoặc lấy mã QR chấm công (Hiệu lực từ 6:00 sáng đến 23:59:59 đêm)
        [HttpPost("generate-qr")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GenerateQrCode()
        {
            var today = DateTime.Today;
            var expiryTime = today.AddDays(1).AddSeconds(-1); // 23:59:59

            var existingQr = await _context.DailyQrCodes
                .FirstOrDefaultAsync(q => q.GeneratedDate.Date == today);

            if (existingQr != null)
            {
                return Ok(new {
                    status = true,
                    qrToken = existingQr.QrCodeToken,
                    expiresAt = existingQr.ExpiryTime
                });
            }

            string token = Guid.NewGuid().ToString();
            var newQr = new DailyQrCode
            {
                QrCodeToken = token,
                GeneratedDate = DateTime.Now,
                ExpiryTime = expiryTime
            };

            _context.DailyQrCodes.Add(newQr);
            await _context.SaveChangesAsync();

            return Ok(new {
                status = true,
                qrToken = newQr.QrCodeToken,
                expiresAt = newQr.ExpiryTime
            });
        }

        // 3. Nhân viên quét mã QR để chấm công (Hỗ trợ 2 lần: Đi làm & Đi về)
        [HttpPost("check-in")]
        [Authorize(Roles = "Employee,User,Admin")]
        public async Task<IActionResult> CheckIn([FromBody] CheckInModel model)
        {
            var username = User.FindFirstValue(ClaimTypes.Name);
            var user = await _userManager.FindByNameAsync(username!);
            if (user == null) 
                return Unauthorized(new { Status = false, Message = "Không tìm thấy thông tin người dùng" });

            // Kiểm tra tính hợp lệ của mã QR
            var qrRecord = await _context.DailyQrCodes.OrderByDescending(q => q.Id).FirstOrDefaultAsync();
            if (qrRecord == null || qrRecord.QrCodeToken != model.QrToken)
            {
                return BadRequest(new { Status = false, Message = "Mã QR không hợp lệ" });
            }

            var currentTime = DateTime.Now;
            if (currentTime > qrRecord.ExpiryTime || currentTime.Hour < 6)
            {
                return BadRequest(new { Status = false, Message = "Mã QR đã hết hạn hoặc ngoài khung giờ chấm công trong ngày (06:00 - 24:00)" });
            }

            var today = DateTime.Today;
            TimeSpan time = currentTime.TimeOfDay;
            TimeSpan h6 = new TimeSpan(6, 0, 0);
            TimeSpan h9 = new TimeSpan(9, 0, 0);
            TimeSpan h17 = new TimeSpan(17, 0, 0);
            TimeSpan h22 = new TimeSpan(22, 0, 0);

            // Tìm bản ghi chấm công của người dùng trong ngày hôm nay
            var existingRecord = await _context.AttendanceRecords
                .FirstOrDefaultAsync(a => a.UserId == user.Id && a.CheckInTime.Date == today);

            if (existingRecord == null)
            {
                // ==================== LẦN 1: CHẤM CÔNG ĐI LÀM ====================
                string status = "";

                if (time >= h6 && time <= h9)
                {
                    status = "Đi làm đúng giờ";
                }
                else if (time > h9 && time <= h17)
                {
                    status = "Đi trễ";
                }
                else
                {
                    // Sau 17:00 (5h chiều) không cho phép chấm công đi làm
                    return BadRequest(new { Status = false, Message = "Bạn không được chấm công ngày hôm nay!" });
                }

                var attendance = new AttendanceRecord
                {
                    UserId = user.Id,
                    CheckInTime = currentTime,
                    Latitude = model.Latitude,
                    Longitude = model.Longitude,
                    Status = status
                };

                _context.AttendanceRecords.Add(attendance);
                await _context.SaveChangesAsync();

                return Ok(new { 
                    Status = true, 
                    Message = $"Chấm công đi làm thành công: {status}", 
                    CheckInTime = currentTime.ToString("yyyy-MM-dd HH:mm:ss"), 
                    AttendanceStatus = status 
                });
            }
            else
            {
                // ==================== LẦN 2: CHẤM CÔNG ĐI VỀ ====================
                if (existingRecord.CheckOutTime != null)
                {
                    return BadRequest(new { Status = false, Message = "Bạn đã hoàn tất chấm công 2 lần (đi làm & đi về) cho ngày hôm nay rồi!" });
                }

                string checkOutStatus = "";

                if (time < h17)
                {
                    checkOutStatus = "Tan làm sớm";
                }
                else if (time >= h17 && time <= h22)
                {
                    checkOutStatus = "Tan làm đúng giờ";
                }
                else
                {
                    // Qua 22:00 (10h tối)
                    checkOutStatus = "Quên chấm công";
                }

                existingRecord.CheckOutTime = currentTime;
                existingRecord.StatusCheckOut = checkOutStatus;
                
                await _context.SaveChangesAsync();

                return Ok(new { 
                    Status = true, 
                    Message = $"Chấm công đi về thành công: {checkOutStatus}", 
                    CheckOutTime = currentTime.ToString("yyyy-MM-dd HH:mm:ss"), 
                    AttendanceStatus = checkOutStatus 
                });
            }
        }

        // 4. Admin lấy danh sách chấm công hiển thị lên DataTable ứng dụng Flutter
        [HttpGet("records")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> GetAttendanceRecords()
        {
            try
            {
                var records = await _context.AttendanceRecords
                    .OrderByDescending(a => a.CheckInTime)
                    .Select(a => new
                    {
                        userName = _context.Users
                            .Where(u => u.Id == a.UserId)
                            .Select(u => u.UserName)
                            .FirstOrDefault() ?? "Không xác định",
                        checkInTime = a.CheckInTime.ToString("yyyy-MM-dd HH:mm:ss"),
                        status = a.Status,
                        checkOutTime = a.CheckOutTime.HasValue ? a.CheckOutTime.Value.ToString("yyyy-MM-dd HH:mm:ss") : "Chưa chấm về",
                        statusCheckOut = a.StatusCheckOut ?? "Chưa chấm về",
                        latitude = a.Latitude,
                        longitude = a.Longitude
                    })
                    .ToListAsync();

                return Ok(records);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { Status = false, Message = $"Lỗi lấy dữ liệu: {ex.Message}" });
            }
        }

        // 5. Admin xuất danh sách chấm công ra file Excel
        [HttpGet("export-excel")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> ExportExcel()
        {
            var records = await _context.AttendanceRecords.ToListAsync();
            var excelBytes = _excelExportService.GenerateAttendanceExcel(records);
    
            var fileName = $"BaoCaoChamCong_{DateTime.Now:yyyyMMddHHmmss}.xlsx";
            return File(excelBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
        }
    }

    // Model DTO hỗ trợ xác thực khuôn mặt
    public class FaceVerifyModel
    {
        public string CurrentFaceBase64 { get; set; } = string.Empty;
    }

    public class CheckInModel
    {
        public string QrToken { get; set; } = string.Empty;
        public string Latitude { get; set; } = string.Empty;
        public string Longitude { get; set; } = string.Empty;
    }
}