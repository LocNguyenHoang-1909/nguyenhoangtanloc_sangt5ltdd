using Microsoft.AspNetCore.Identity;

namespace nguyenhoangtanlocapi_sangt5ltdd.Models
{
    public class User : IdentityUser
    {
        public string? Initials { get; set; }
        public string? FaceImage { get; set; }
    }
}