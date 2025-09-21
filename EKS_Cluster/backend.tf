terraform {
    backend "s3" {
        bucket = "filmcastpro-state-bucket"
        key = "terraform.tfstate"
        region = "us-east-1"
        encrypt = true
        dynamodb_table = "filmcastpro-dynamodb-table"
    }   
}