class RegisterRequestDto {
  String username;
  String email;
  String password;
  String confirmPassword;

  new(this.username, this.email, this.password, this.confirmPassword);
}
