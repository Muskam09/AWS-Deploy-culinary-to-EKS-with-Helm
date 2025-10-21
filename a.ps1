aws iam create-policy `
    --policy-name AWSLoadBalancerControllerIAMPolicy `
    --policy-document file://iam_policy.json


eksctl create iamserviceaccount `
  --cluster=eks-cluster-smachno `
  --namespace=kube-system `
  --name=aws-load-balancer-controller `
  --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy `
  --override-existing-serviceaccounts `
  --region eu-central-1 `
  --approve

helm install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n kube-system `
  --set clusterName=eks-cluster-smachno `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller `
  --set region=eu-central-1 `
  --set vpcId=vpc-075ba230f11ea6141 # Ваше значення


eksctl delete iamserviceaccount `
  --cluster=eks-cluster-smachno `
  --namespace=kube-system `
  --name=aws-load-balancer-controller `
  --region=eu-central-1

helm uninstall aws-load-balancer-controller -n kube-system
# DB
helm install db-release ./database -f ./database/values.yaml -f ./database/secrets.yaml
helm uninstall db-release
#back
helm upgrade --install backend-release ./helm-backend -f ./helm-backend/values.yaml -f ./helm-backend/secrets.yaml
helm uninstall backend-release
#front
helm upgrade --install frontend-release ./helm-frontend
helm uninstall frontend-release


# Для створення бд IAM Роль
eksctl create iamserviceaccount `
  --cluster=eks-cluster-smachno `
  --namespace=kube-system `
  --name=ebs-csi-controller-sa `
  --attach-policy-arn=arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy `
  --approve `
  --region=eu-central-1

helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver `
  --namespace kube-system `
  --set controller.serviceAccount.create=false `
  --set controller.serviceAccount.name=ebs-csi-controller-sa

#--set grafana.grafana\.ini.server.root_url потрібно свою вказати
helm install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --set grafana.service.type=NodePort `
  --set grafana.grafana\.ini.server.root_url="http://k8s-smachnogroup-b61c0417ea-523905447.eu-central-1.elb.amazonaws.com/grafana/" `
  --set grafana.grafana\.ini.server.serve_from_sub_path=true `
  --reuse-values
