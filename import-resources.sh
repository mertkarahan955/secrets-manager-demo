#!/bin/bash

echo "🔄 Importing existing AWS resources to Terraform state..."

cd terraform

# Import existing resources
echo "Importing ALB..."
terraform import aws_lb.app arn:aws:elasticloadbalancing:eu-west-1:489335433461:loadbalancer/app/secrets-manager-poc-alb/35e7210b1dd78579

echo "Importing Target Group..."
terraform import aws_lb_target_group.app arn:aws:elasticloadbalancing:eu-west-1:489335433461:targetgroup/secrets-manager-poc-tg/05877dc21dbc5ade

echo "Importing DynamoDB table..."
terraform import aws_dynamodb_table.terraform_state_lock terraform-state-lock

echo "Importing CloudWatch Log Group..."
terraform import aws_cloudwatch_log_group.app /ecs/secrets-manager-poc

echo "Importing IAM roles..."
terraform import aws_iam_role.ecs_execution_role secrets-manager-poc-ecs-execution-role
terraform import aws_iam_role.ecs_task_role secrets-manager-poc-ecs-task-role

echo "✅ Import completed! Now run terraform plan to see the current state."
