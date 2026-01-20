import boto3

def main():
    sts = boto3.client("sts")
    ident = sts.get_caller_identity()
    region = boto3.session.Session().region_name

    print("✅ AWS identity")
    print("  Account:", ident["Account"])
    print("  Arn:", ident["Arn"])
    print("  UserId:", ident["UserId"])
    print("✅ Default region:", region or "(not set)")

if __name__ == "__main__":
    main()
