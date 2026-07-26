output "document_state_machine_name" {
  value = aws_sfn_state_machine.document_state_machine.name
}

output "document_state_machine_arn" {
  value = aws_sfn_state_machine.document_state_machine.arn
}
