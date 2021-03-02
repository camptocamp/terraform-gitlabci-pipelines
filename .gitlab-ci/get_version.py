# Python version: 2.7.17
# Requires: pip install requests semantic_version pyhcl
import argparse
import requests
import json
import semantic_version
import hcl
from distutils.version import LooseVersion

# semantic_version doesn't support whitespaces nor '~>'
def format_constraint(hcl_format):
    sem_format = hcl_format.replace(' ', '')
    if '~>' in sem_format:
        sem_format = sem_format.replace('~>', '>=') \
                +','+ \
                '<'+ str(semantic_version.Version(sem_format.replace('~>', '')).next_minor())
    return sem_format

def get_token(uname, upass):
    url = 'https://hub.docker.com/v2/users/login/'
    data = {'username': '%s' %uname, 'password': '%s' %upass}
    request = requests.post(url, data=data)
    token = request.json()['token']
    return token

def get_versions(repo, token):
    def get_page(page):
        url = 'https://hub.docker.com/v2/repositories/' \
                + repo +'/tags/?page='+ str(page) +'&page_size=100'
        headers = {'Authorization': 'JWT %s' %token}
        single_page = requests.get(url, headers=headers).json()
        return [item.get('name') for item in single_page['results']]
    page = 1
    versions = []
    while get_page(page):
        versions = versions + get_page(page)
        page += 1
    return versions

def main(args):
    input_file=open(args.file, 'r')
    try:
        constraint = hcl.load(input_file)['terraform']['required_version']
    except:
        # Using the latest version
        constraint = '>= 0.1.0'
    token = get_token(args.username, args.password)
    all_versions = sorted(get_versions(args.repository, token), key=LooseVersion)
    # Get the required versions range
    valid_versions = semantic_version.SimpleSpec(format_constraint(constraint))
    while all_versions:
        match = all_versions.pop()
        if semantic_version.validate(match) \
                and not(semantic_version.Version(match).prerelease) \
                and semantic_version.Version(match) in valid_versions:
            # Valid x.y.z & release & in the required versions range
            break
        match = 'No match'
    print(match)

if __name__ == '__main__' :
    parser = argparse.ArgumentParser()
    parser.add_argument('-u','--username', help='Dockerhub username', required=True)
    parser.add_argument('-p','--password', help='Dockerhub password', required=True)
    parser.add_argument('-r','--repository', help='Dockerhub repository', required=True)
    parser.add_argument('-f','--file', help='path/to/version.tf', required=True)
    args = parser.parse_args()
    main(args)
