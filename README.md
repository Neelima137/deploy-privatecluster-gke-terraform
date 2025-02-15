# deploy-privatecluster-gke-terraform

This Terraform configuration creates a private GKE cluster in Google Cloud, with a jump host for accessing the cluster via SSH using IAP, a NAT gateway for internet access, a service account for GKE nodes, and necessary networking resources. 

![image](https://github.com/user-attachments/assets/11a05ff3-93d8-41eb-ab13-f2d90446882a)


Step1: Lets create a folder for all of your Terraform source code files. Let’s call it “cluster”
```
mkdir cluster
cd cluster
```
Step2: Create a new file for the configuration block.
```
$ touch provider.tf
$ touch main.tf
$ touch variables.tf
```
Step3: 
Run terraform init
terraform fmt
terraform validate
terraform plan
terraform apply

Step4: lets Connect your private cluster
Download the IAP desktop using the following link : https://github.com/GoogleCloudPlatform/iap-desktop/wiki/Installation
after instalation , sign in to your gcp account 
select the jump-host vm , Right-click on jump-host and connect it. you should be in.

Step5: SSH into the Jump Host
SSH into the VM test-1-jump-host using the internal IP 10.0.0.7:
Step6:  Authenticate with Google Cloud
```
gcloud auth login
```
You will be prompted with a link. Copy and paste it into a browser, authorize the account, and then enter the authorization code back into the terminal. Once done, you should be authenticated.

Stepp6: Install kubectl
```
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
For more details on installing kubectl, refer to the official documentation:  https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

Step7: Run the following command to configure your kubectl to use the credentials of your GKE cluster:
```
gcloud container clusters get-credentials test-1-cluster --region us-central1 --project [project-id]
```
Step8: If you encounter an error, install the GKE authentication plugin:
```
sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
```
![image](https://github.com/user-attachments/assets/d38f37d5-53af-4d86-a0f6-574dc846cf69)

Step9: Check the nodes in the cluster to ensure you're properly connected:
```
kubectl get nodes
```
Step10: Deploy an Application Using a YAML File
```
vi deploy.yaml
```
(Paste the appropriate YAML configuration for your deployment into the file.)

Step11: Apply the YAML file to create the resources:
```
kubectl apply -f deploy.yaml
```
Step12: Check Pods and Services :
```
kubectl get pods
```
List the services to check for the load balancer's external IP:
```
kubectl get svc
```
Wait a moment for the service to initialize.
![image](https://github.com/user-attachments/assets/a0bc003e-2a14-4385-89b7-6ce9520edbf2) 

Step13:
Access the Application
The external IP of the load balancer will eventually appear in the EXTERNAL-IP column under the services. You can access the service using the external IP on port 80.

Alternatively, go to the Google Cloud Console, navigate to the Services section, and click on the endpoint to be redirected to the welcome page (e.g., NGINX default page).

![image](https://github.com/user-attachments/assets/7d2736f6-09b2-4cea-9066-162d956b6be4)

![image](https://github.com/user-attachments/assets/96533783-ff5b-452d-9a57-91f79b10fbb8)




















