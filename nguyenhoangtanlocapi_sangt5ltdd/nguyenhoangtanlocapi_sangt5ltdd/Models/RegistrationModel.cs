namespace nguyenhoangtanlocapi_sangt5ltdd.Models
{
    public class RegistrationModel
    {
        public required string Username { get; set; }
        public required string Email { get; set; }
        public required string Password { get; set; }
        public string? Initials { get; set; }
        public string? Role { get; set; }
        public string? FaceImage { get; set; }
    }
}