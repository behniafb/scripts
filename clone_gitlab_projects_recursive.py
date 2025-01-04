import os
import requests
import subprocess

# Configuration
GITLAB_URL = "https://gitlab.eclipse.org"
TOP_GROUP = "6438"  # Group ID
ACCESS_TOKEN = "token"  # Replace with your GitLab personal access token
CLONE_DIR = "./cloned_projects"  # Base directory to store cloned repositories

# Headers for GitLab API authentication
HEADERS = {"Authorization": f"Bearer {ACCESS_TOKEN}"}


def fetch_group_projects(group_id):
    """
    Fetch all projects in a group (non-recursive).
    """
    url = f"{GITLAB_URL}/api/v4/groups/{group_id}/projects"
    projects = []
    page = 1
    while True:
        response = requests.get(url, headers=HEADERS, params={"per_page": 100, "page": page})
        response.raise_for_status()
        data = response.json()
        if not data:
            break
        projects.extend(data)
        page += 1
    return projects


def fetch_subgroups(group_id):
    """
    Fetch all subgroups of a group using their IDs.
    """
    url = f"{GITLAB_URL}/api/v4/groups/{group_id}/subgroups"
    subgroups = []
    page = 1
    while True:
        response = requests.get(url, headers=HEADERS, params={"per_page": 100, "page": page, "all_available": True})
        response.raise_for_status()
        data = response.json()
        if not data:
            break
        subgroups.extend(data)
        page += 1
    return subgroups


def clone_repo(repo_url, target_dir):
    """
    Clone a repository to the specified directory using HTTPS.
    Skip cloning if the target directory already exists.
    """
    repo_name = os.path.basename(repo_url).replace(".git", "")
    repo_dir = os.path.join(target_dir, repo_name)

    # Check if the repository is already cloned
    if os.path.exists(repo_dir):
        print(f"Skipping {repo_name}: already cloned in {repo_dir}")
        return

    # Clone the repository
    print(f"Cloning {repo_name} into {repo_dir}")
    subprocess.run(["git", "clone", repo_url, repo_dir], check=True)


def clone_group_repos(group_id, parent_dir):
    """
    Recursively clone all projects in a group and its subgroups using group IDs.
    Maintain subgroup directory structure.
    """
    print(f"Fetching group ID: {group_id}")
    group_url = f"{GITLAB_URL}/api/v4/groups/{group_id}"
    response = requests.get(group_url, headers=HEADERS)
    response.raise_for_status()
    group = response.json()

    # Create the directory for this group
    group_dir = os.path.join(parent_dir, group["name"])
    os.makedirs(group_dir, exist_ok=True)

    # Clone all projects in the group
    projects = fetch_group_projects(group["id"])
    for project in projects:
        clone_repo(project["http_url_to_repo"], group_dir)

    # Recursively clone all subgroups
    subgroups = fetch_subgroups(group["id"])
    for subgroup in subgroups:
        clone_group_repos(subgroup["id"], group_dir)


if __name__ == "__main__":
    print(f"Cloning all projects under group ID: {TOP_GROUP}")
    clone_group_repos(TOP_GROUP, CLONE_DIR)
    print("All projects cloned successfully.")

