# Git LFS Locking
- [Git LFS Locking](#git-lfs-locking)
  - [References](#references)
  - [Installing Git LFS](#installing-git-lfs)
  - [Configure Exclusive File Locks](#configure-exclusive-file-locks)
  - [Configure Lockable Files Read-Only](#configure-lockable-files-read-only)
  - [Working with Lockable Files](#working-with-lockable-files)
    - [**1. Get Latest File Version** -](#1-get-latest-file-version--)
    - [**2. Lock File** -](#2-lock-file--)
    - [**3. Make & Merge Changes** -](#3-make--merge-changes--)
    - [**4. Unlock Files** -](#4-unlock-files--)
  - [Auto-unlock Pipeline](#auto-unlock-pipeline)
    - [Enabling the Pipeline to perform unlocks on your behalf](#enabling-the-pipeline-to-perform-unlocks-on-your-behalf)

## References
- [Terms and Acronyms](./terms.md)
- [GitHub Large File Storage](https://git-lfs.github.com/)
- [GitHub File Locking](https://github.com/git-lfs/git-lfs/wiki/File-Locking)
- [GitLab File Locking](https://docs.gitlab.com/ee/user/project/file_lock.html)
  
## Installing Git LFS
Make sure you have Git LFS installed in your computer:
```bash
git-lfs --version
```
If it doesn’t recognize git lfs commands, you must install it. You only have to do this once per repository per machine:
```bash
git lfs install
```
Each Git LFS subcommand is documented in the official [man pages](https://github.com/git-lfs/git-lfs/tree/main/docs/man). Any of these can also be viewed from the command line:
```bash
git lfs help <command>
git lfs <command> -h
```

## Configure Exclusive File Locks
You need the Maintainer role to configure Exclusive File Locks for your project through the command line.

The first thing to do before using File Locking is to tell Git LFS which kind of files are lockable. The following command stores PNG files in LFS and flag them as lockable:
```bash
git lfs track "*.png" --lockable
```
After executing the above command, a file named `.gitattributes` is created or updated with the following content:
```
*.png filter=lfs diff=lfs merge=lfs -text lockable
```
You can also register a file type as lockable without using LFS. To do that you can edit the `.gitattributes` file manually:

```bash
*.pdf lockable
```
The `.gitattributes` file is key to the process and must be pushed to the remote repository for the changes to take effect.

After a file type has been registered as lockable, Git LFS makes them read-only on the file system automatically. This means you must **lock the file** before editing it

## Configure Lockable Files Read-Only
```lfs.setlockablereadonly``` tells Git LFS how to interpret what "locked" means. When true, it tells Git LFS to make files that are lockable and not locked by the current user read-only, while files locked by the current user are writeable. To configure this setting, use:
```bash
git config lfs.setlockablereadonly 'true/false'
```

## Working with Lockable Files
::: mermaid
graph LR
    A(Pull) --> B(Lock);
    B --> C(Make & Merge Changes);
    C --> D(Unlock Files);
    D --> A;
:::

### **1. Get Latest File Version** - 
Perform a pull from `origin/develop` to ensure you are starting from the latest version of any binary files you intend to modify.

### **2. Lock File** - 
When you are ready to edit files, run the `lock` command. This attempts to register the file as locked in your name on the server.
```
git lfs lock images/foo.jpg
```
If successful, you will see:
```
Locked images/foo.jpg
```
If unsuccessful, you will see:
```
Lock failed: There is an existing lock on this path.
```
You can view current file locks with the locks command.
```
$ git lfs locks
images/bar.jpg  jane   ID:123
images/foo.jpg  alice  ID:456
```
### **3. Make & Merge Changes** -
The file will also be ready for you to edit, push, and merge. Git LFS will verify that you're not modifying a file locked by another user when pushing. Maintain file locks until your changes have been successfully merged into ```origin/develop```. 
   
### **4. Unlock Files** - 
After changes have been merged into `origin/develop`, or if at any time you decide you don't need the lock, you can remove it by passing the path or ID to the `unlock` command.
```
$ git lfs unlock images/foo.jpg
$ git lfs unlock --id=456
```
You can also unlock someone else's file with the --force flag:
```
$ git lfs unlock images/foo.jpg --force
```

## Auto-unlock Pipeline
The [azdo-unlock-changed-files.ps1](../task-scripts/azdo-unlock-changed-files.ps1) script can be configured to run against in a release pipeline on a repository after a merge into a specific branch (e.g. `develop`). No parameters need to be passed, but it will only run on the primary artifact for that release pipeline, which should be the repository for which you want files unlocked.
::: mermaid
graph LR
    A(Get locked files) --> B(Get changed files);
    B --> C(Unlock changed & locked files);
:::
### Enabling the Pipeline to perform unlocks on your behalf
1. Create a [Personal Access Token](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page) with permissions to the applicable repo
2. Store your PAT in the DEVOPS_LIFECYCLE project's [global library](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_library?itemType=VariableGroups&view=VariableGroupView&variableGroupId=23&path=global)
   - Variable Name = `USERNAME` portion of email to uppercase and replacing `.` with `_`  + `_GITPAT`
        <center>

            e.g. if email = john.doe@server.com, then variable name = JOHN_DOE_GITPAT

        </center>
   - Variable Value = `PAT value`
   - Change variable type to secret to mask the value
1. Map the variable as Environment Variable for [AZDO unlock changed files](https://dev.azure.com/WrightMedical/DEVOPS_LIFECYCLE/_taskgroup/0cc805c6-e2bf-42bb-8843-94c5dde29647) task group
