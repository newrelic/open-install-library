output distros {
  value = var.distros
}

output users {
  value = var.ami_users
}

output ip {
  value = aws_instance.install_test_instance.*.public_ip
}
