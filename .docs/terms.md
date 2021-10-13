# Terms, Acronyms, and Definitions

## Azure DevOps
- **Variable Groups** - Variable groups store values and secrets that you might want to use across multiple pipelines in the same project.
- **Release Pipeline** - Pipelines represent manageable and repeatable configurations for executing tasks (e.g. releasing software) that can be organized into jobs and stages (e.g. development, QA, and production).
- **Pipeline Agents** - An agent is computing infrastructure with installed agent software that runs pipeline jobs.
- **Terraform** - Terraform is an open-source infrastructure as code software tool that provides a consistent CLI workflow to manage & deploy cloud services. 

## Source Code & Repositories
- **Source Code Management** - Source Code Management (SCM) is used to track modifications to a source code repository.
- **Binary File** - A binary file is a computer file that is not a text file.
- **Branch** - A version of the repository that diverges from the main working project. Branches can be a new version of a repository, experimental changes, or personal forks of a repository for users to alter and test changes.
- **Checkout** - The git checkout command is used to switch branches in a repository. git checkout testing-el would take you to the _testing-el_ branch whereas git checkout master would drop you back into master. Be careful with your staged files and commits when switching between branches.
- **Cherry-picking** - When cherry-picking a commit in Git, you are taking an older commit, and rerunning it at a defined location. Git copies the changes from the original commit, and then adds them to the current location.
- **Clone** - A clone is a copy of a repository or the action of copying a repository. When cloning a repository into another branch, the new branch becomes a remote-tracking branch that can talk upstream to its origin branch (via pushes, pulls, and fetches).
- **Commit** –

    *As a noun*: A single point in the Git history; the entire history of a project is represented as a set of interrelated commits.

    *As a verb*: The action of storing a new snapshot of the project&#39;s state in the Git history, by creating a new commit representing the current state of the index and advancing HEAD to point at the new commit.

- **Fetch** - By performing a Git fetch, you are downloading and copying that branch&#39;s files to your workstation. Multiple branches can be fetched at once, and you can rename the branches when running the command to suit your needs.
- **Fork** - Creates a copy of a repository.
- **Git** - a version control system which enables you to track changes to files.
- **Git LFS** - Git Large File Storage (LFS) replaces large files such as audio samples, videos, datasets, and graphics with text pointers inside Git, while storing the file contents on a remote server like GitHub.com or GitHub Enterprise
- **HEAD** - a pointer to the most recent commit on the current branch.
- **Main** - The default branch.
- **Merge** - To bring the contents of another branch (possibly from an external repository) into the current branch. In the case where the merged-in branch is from a different repository, this is done by first fetching the remote branch and then merging the result into the current branch. This combination of fetch and merge operations is called a pull. Merging is performed by an automatic process that identifies changes made since the branches diverged, and then applies all those changes together. In cases where changes conflict, manual intervention may be required to complete the merge.
- **Origin** - the default name for a remote repository
- **Pull/Pull Request** - If someone has changed code on a separate branch of a project and wants it to be reviewed to add to the master branch, that someone can put in a pull request. Pull requests ask the repo maintainers to review the commits made, and then, if acceptable, merge the changes upstream. A pull happens when adding the changes to the master branch.
- **Push** - Updates a remote branch with the commits made to the current branch. You are literally &quot;pushing&quot; your changes onto the remote.
- **Remote** - A copy of the original branch. When you clone a branch, that new branch is a remote, or _clone_. Remotes can talk to the origin branch, as well as other remotes for the repository, to make communication between working branches easier.
- **Repository** (&quot;Repo&quot;) - the object database of the project, storing everything from the files themselves, to the versions of those files, commits, deletions, et cetera. Repositories are not limited by user, and can be shared and copied (see: [fork](https://linuxacademy.com/blog/linux/git-terms-explained/#fork)).
- **Tag** - used to mark a point in the commit ancestry chain.
- **Workspace** – (also local repository) an individual&#39;s local copy of a Git repository