## General lessons learned:

- In the buildspec, when wanting to put a multi-line command into the ``commands`` object, use the ``>`` character.  Know that any newlines will be folded into a single line separated by whitespace.
- In the Packer template, use the 'ami_regions' field to instruct Packer to copy the AMI to multiple regions
- Use the ``-machine-readable`` flag to get output from Packer that is more easily parsed
- Best practice with CodeBuild is to put multiple shell commands or scripts into a separate shell script file and execute it from the buildspec
- Parameter Store will strip string values of any embedded carriage returns, potentially corrupting the data
