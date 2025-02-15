terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.20.0"
    }
  }
}
provider "google" {
  region  = "us-central1"
  project = "cts07-devadin"

}

