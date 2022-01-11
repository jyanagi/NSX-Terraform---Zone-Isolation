<h1> NSX-T Zone Isolation Infrastructure-as-Code </h1>
<p> This repository provides a sample Terraform script which deploys software-defined networking and security components to enable organizations to obtain zero-trust within their data centers and deliver multi-tenancy with true isolation on a common hardware platform.</p>
<p> The environment deployed are three (3) zones: Shared Services, Developer A (blue), and Developer B (green).</p>
<p> Shared Services is able to communicate to both Blue and Green networks, respectively</p>
<p> Blue and Green networks are not able to communicate with each other and within their own subnets through Gateway Firewall and Distributed Firewall security policies.</p>
<h2> Deploy </h2>
<p> Note:  Terraform must be installed</p>
<p> 1. Clone this GIT repository </p>
<p> 2. Run the command "terraform init" </p>
<p> 3. Run the command "terraform plan" </p>
<p> 4. Run the command "terraform deploy -auto-approve </p>
