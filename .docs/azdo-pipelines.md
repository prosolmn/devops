# Azure DevOps Pipelines

- [Azure DevOps Pipelines](#azure-devops-pipelines)
  - [References](#references)
  - [DevOps & Lifecycle Project](#devops--lifecycle-project)
  - [Environments](#environments)
  - [Libraries](#libraries)
  - [Repos](#repos)
    - [Terraform](#terraform)
    - [Infra](#infra)
  - [Releases](#releases)
    - [**Artifacts**](#artifacts)
    - [**Triggers**](#triggers)
    - [**Stages**](#stages)
    - [**Release Pipelines**](#release-pipelines)
      - [**CD-DEV**](#cd-dev)
      - [**aws_cognito**](#aws_cognito)
      - [**lfs-unlock**](#lfs-unlock)
      - [**release**](#release)
      - [**test**](#test)

## References
- [Terms and Acronyms](./terms.md)
- [Azure DevOps / WrightMedical / DEVOPS_LIFECYCLE](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/)
- [Azure DevOps / WrightMedical / DEVOPS_LIFECYCLE / Infra Repository](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_git/infra)
- [Wright Medical / Share Drive / DevOps](\\us.wmgi.com\root\Shared\DevOps)
- [Microsoft Docs / Classic Release Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/release/define-multistage-release-process?view=azure-devops)
- [Microsoft Docs / Add & use variable groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=classic)
- [Microsoft Docs / Azure Pipeline Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser)
- [Microsoft Docs / PowerShell](https://docs.microsoft.com/en-us/powershell/)
  
## DevOps & Lifecycle Project
The DEVOPS_LIFECYCLE Project contains all release and infrastructure related values, repositories, and pipelines. The project consolidates DevOps functions across all development teams under the WrightMedical org group. Access the project via the [link](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/), above.


## Environments
Environments represent siloed infrastructure to where microservice components can be deployed and tested. Environments enable development teams to progress microservices and infrasture through various stages concurrently. (e.g. developers can be testing a new feature while formal qa is done on an older version of the same microservice). The following environments are currently utilized:
* Edge
* Test
* Blu
* Grn

Edge and Test are development environments on the WrightProphecyDev account, while blu and grn are environments on the WrightProphecyProd account. Blu and Grn may be production (customer facing) environments that undergo QA before being released to Prod.

## Libraries
A library is a collection of assets (variable groups or secure files). Variable groups contain sets of Name:Value pairs. Assets defined in a library can be used in multiple build and release pipelines of the project. Variable groups are leveraged for multiple purposes:
* maintain consistent values amoung pipelines
* faciliate extensible pipeline tasks that utilize consistent variable names that:
  * have varying values by stages
  * have varying values by target aws account or environment
* to store encrypted values

Primary variable groups are:
* global
* awsAcct{Dev|Prod}
* stage{Edge|Dev|Test|QA|Prod}
* env{blu|grn}*

*Blu and grn environments are independant of stages, so have their own env variable groups, where the other environment's values are stored in their stage variable group.

## Repos
Two primary repos are stored within the DEVOPS_LIFECYCLE Project. 

### [Terraform](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_git/terraform/) 
contains IaaC, including terraform files and values (tfvars) and relevant tools (scripts). 
### [Infra](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_git/infra/) 
contains everything else, including pipeline task scripts & modules, aws configuration templates (e.g. API Gateway definitions), and stage or environment variable definitions.

## Releases

### **Artifacts**
An artifact is the input object of a release pipeline. It is typically a build artifact (e.g. software component), but can also incluse a repository. Most release pipelines include the 'infra' repo, which contains task-scripts and configuration values integral to release pipeline tasks.

### **Triggers**
Triggers specify the event conditions to automatically create a release or deploy to a stage. You can set up triggers for artifact events (pull requests or merges to specific branches) or on a schedule.

You can manually create a release or deploy to a stage where triggers have not automatically done so.

### **Stages**
Stages are logical boundaries representing major divisions in a pipeline. Stages can have pre and post-deployment conditions (e.g. triggers, approvals, and gates). Our primary use of stages is to represent and facilitate the software development lifecycle. The development team progresses software and infrastructure through the following stages:
* Edge
* Test
* QA
* Prod

[Continuous Delivery pipelines](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_release?_a=releases&view=all&path=%5CCD-dev) deploy individual microservices to these designated stages. Triggers are configured based on the established [branching strategy](.\branching-branching-strategy.md). When a build is completed from a designated branch, a release will automatically be created and the build (i.e. artifact) will be deployed to the stage that corresponds to the triggering branch (e.g. builds from a develop branch, representing integration-test ready software, will automatically deploy to the test stage.)

### **Release Pipelines**
A release pipeline consists of the task/job instructions and any service connections, secrets, and variables or values needed to execute the tasks. A release is the execution of a release pipeline. A release must be created before you can execute jobs and tasks within stages (i.e. deploy to a stage). 

Many release tasks are grouped into task groups and many utilize scripts source controlled within this Infra Repository (Refereneces section above). To view the pipeline's tasks, edit the pipeline and navigate to the desired stage; right click any task group and select 'manage task group' option to drill down into that task group. This process can be repeated until the base tasks are found. Task parameters, usually in the form of variables, must be passed down through the entire chain, originating from a stored value or system variable, for a value to successfully be utilized.

WrightMedical Releases are organized into the following groups:

#### **CD-DEV**
Each microservice should have it's own Continuous Deployment pipeline. This pipeline will deploy the microservice to its intended target based on the build or updated branch. Microservices of the same type or with the same target utilize task groups to minimize maintenance across the many pipelines.
- Container Microservice Pipelines utilize
- Lambda Function Pipelines utilize
- API Gateway
- Terraform

#### **aws_cognito**
Cognito Pools can be exported and users can be updated from these pipelines. 

#### **lfs-unlock**
See [Git LFS Locking](./git-lfs-locking.md) for details regarding LFS locks. lfs-unlock pipelines should be created with CI triggers for each repository that utilizes LFS locks for binary files. These pipelines will automatically unlock files in the latest PR.

#### **release**
This folder contains all production release pipelines. The current release pipeline is [Prophecy Release - blu/grn](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_release?_a=releases&view=all&definitionId=34). 
>Ensure the ```envLibrary``` value of the ```awsAcctProd``` Library is set to the correct environment library (e.g. envBlu) before the release is created.

#### **test**
Test contains both Integration V&V test pipelines as well as pipeline testing for the DevOps project.