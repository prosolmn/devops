# Branching Strategy
- [Branching Strategy](#branching-strategy)
  - [References](#references)
  - [Branching goals](#branching-goals)
  - [The develop branch](#the-develop-branch)
  - [The master branch](#the-master-branch)
  - [Support branches](#support-branches)
    - [Feature branches](#feature-branches)
    - [Release branches](#release-branches)
    - [Hotfix branches](#hotfix-branches)

## References
- [Terms and Acronyms](./terms.md#source-code-management-scm)
- [gitflow](https://datasift.github.io/gitflow/IntroducingGitFlow.html)

## Branching goals

As an individual, I need to

- Have the history of my changes
- Be able to compare my changes and revert them if necessary
- Be able to develop and deploy a bugfix without affecting the features I am currently working on

As a team, besides the requirements above, I need to

- Be able to work and to push changes to the server without affecting my coworkers
- Merge my changes with my coworkers&#39;s and to solve any conflicts in the simplest way possible
- Ensure the quality/ basic standards of the code regardless of the number of people involved

<center>

**Figure 16.0 Branching Strategy**

![branching-strategy.jpg](./.attachments/branching-strategy.jpg)

</center>

## The develop branch

The central repo holds one main branches with an infinite lifetime:

> develop

We consider origin/develop to be the main branch where the source code reflects an _integration-__test ready_ state.

Perform code reviews before merges into develop.

## The master branch

The central repo holds one main branches with an infinite lifetime:

> master

We consider origin/master to be the main branch where the source code reflects the production release state.

Merges into master after every production release.

## Support branches

Next to the develop branch, our development model uses a variety of supporting branches to aid parallel development between team members, ease tracking of features, prepare for production releases and to assist in quickly fixing live production problems. Unlike the main branch, these branches may have a limited life time.

The different types of branches we may use are:

- Feature branches
- Release branches
- Hotfix branches

### Feature branches

May branch off from:

>develop, release, hotfix

Must merge back into:

> [source branch]

Branch naming convention:
```
/feature/*

/fix/*
```
\* : anything except master, release\*, develop\*, or hotfix\*

Feature branches (or topic branches) are used to develop new features for future release. The feature branch exists as the feature is developed and will eventually be merged back into master (to add the new feature to an upcoming release) or discarded.

Note: Feature branches may exist in developer repos but should be pushed often when collaborating with other developers on that feature.

Note2: Feature branches should be discarded after being merged into develop.

### Release branches

May branch off from:

> develop

Branch naming convention:
```
/release/*
```
Release branches support preparation of a new production release. All features that are targeted for the release-to-be-built must be merged in to develop. All features targeted at future releases may not—they must wait until after the release branch is branched off.

### Hotfix branches

May branch off from:

> master

May merge back into:

> master, develop

Branch naming convention:
```
/hotfix/*
```
Hotfix branches are very much like release branches but arise from the necessity to act immediately upon an undesired state of a live production version. When a critical bug in a production version must be resolved immediately, a hotfix branch may be branched off from the corresponding tag on the master branch that marks the production version.

Work on the develop and feature branches can continue while preparing a quick production fix.