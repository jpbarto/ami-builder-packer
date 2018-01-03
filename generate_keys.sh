#!$(which bash)

REGION='eu-central-1'
IMAGE_ID='ami-1234567890abc'
PRIVATE_KEY=''
PUBLIC_KEY=''

function generate_keys {
    # generate a key for use
    openssl genrsa -out private.pem 2048
    # export the public key
    openssl rsa -in private.pem -outform PEM -pubout -out public.pem
    PRIVATE_KEY=`base64 -i private.pem -o -`
    PUBLIC_KEY=`base64 -i public.pem -o -`
    echo "Private Base64 ${PRIVATE_KEY}"
    echo "Public Base64 ${PUBLIC_KEY}"
}

# sign the AMI text
function create_ami_signature {
    echo "${REGION}:${IMAGE_ID}\c" > ami.txt
    echo ${PRIVATE_KEY} | base64 -D > tmp_private.pem
    openssl dgst -sha256 -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 -sign tmp_private.pem -out ami.txt.sign ami.txt

    IMAGE_SIGNATURE=`base64 -i ami.txt.sign -o -`
    echo IMAGE_SIG Base64 ${IMAGE_SIGNATURE}
    IS_PART1=`echo ${IMAGE_SIGNATURE} | cut -b 1-200`
    IS_PART2=`echo ${IMAGE_SIGNATURE} | cut -b 201-400`
    echo PART 1 ${IS_PART1}
    echo PART 2 ${IS_PART2}
}

# retrieve part 1 and part 2 of sig from image tags
# retrieve public key from parameter store
function validate_signature {
    echo ${IS_PART1}${IS_PART2} | base64 -D > my_ami.sign
    echo ${PUBLIC_KEY} | base64 -D > my_pub_key.pem
    openssl dgst -sha256 -sigopt rsa_padding_mode:pss -sigopt rsa_pss_saltlen:-1 -verify my_pub_key.pem -signature my_ami.sign ami.txt
}

function cleanup_files  {
    rm private.pem public.pem tmp_private.pem my_pub_key.pem 2>/dev/null
    rm ami.txt my_ami.sign ami.txt.sign 2>/dev/null
}

generate_keys 
cleanup_files
