# http://requests.readthedocs.org/en/latest/
# https://github.com/mkleehammer/pyodbc/wiki
# https://openpyxl.readthedocs.io/en/stable/

# Commons
from pub_oapi_tools_common import aws_lambda
from pub_oapi_tools_common import ucpms_db
from pub_oapi_tools_common.misc import log
from pub_oapi_tools_common.misc import output_dict_list_to_csv

# Internal imports
import csv
import argparse
import os
from pprint import pprint

# External imports
import requests
import openpyxl


# Process arguments
parser = argparse.ArgumentParser()

parser.add_argument("-fy", "--ostifyfiles",
                    dest="process_osti_fy_files",
                    action="store_true",
                    default=False,
                    help="Optional. Process the OSTI FY xlsx files (upload these to /input).")

parser.add_argument("-g", "--googledrive",
                    dest="transfer_to_google_drive",
                    action="store_true",
                    default=True,
                    help="Optional. Uploads resulting files to the lbl tableau data google drive.")

args = parser.parse_args()


# ========================================
def main():

    # Creates a datestamped output folder
    create_output_dir()

    # Connect to LBL's HR feed API and download 1 file
    get_lbl_hr_feed()

    # Connect to the reporting DB and download 3 files
    get_reporting_db_data()

    # Load the OSTI FY xlsx workbooks, export LBNL sheet as .csv
    if args.process_osti_fy_files:
        export_osti_fy_data()

    # Transfer output files to google drive
    if args.transfer_to_google_drive:
        transfer_to_google_drive()

    log("INFO", __name__, "Program complete. Exiting.")


# ----------------------------------------
def create_output_dir():
    from datetime import datetime
    global output_dir

    today_string = datetime.today().strftime('%Y-%m-%d-%H-%M-%S')
    output_dir = f'output/{today_string}'
    os.mkdir(output_dir)

    log("INFO", __name__, f"Updated files will be output to: {output_dir}")


# ----------------------------------------
def output_json_to_csv(json_array, output_file_name):
    # Output file
    with open(output_dir + "/" + output_file_name, 'w') as csv_file:
        csv_writer = csv.writer(csv_file)
        csv_writer.writerow(json_array[0].keys())
        for row in json_array:
            csv_writer.writerow(row.values())


# ----------------------------------------
def get_lbl_hr_feed():

    # Get params from AWS
    param_req = {
        "lbl-hr-feed": {
            "folder": "pub-oapi-tools/lbl-api",
            "names": ['endpoint', 'client-id', 'client-secret']}}
    creds = aws_lambda.get_parameters(param_req=param_req, verbose=False)
    creds = creds['lbl-hr-feed']

    print("Connecting to LBL's API and downloading HR feed.")
    result = requests.get(
        creds['endpoint'],
        stream=True,
        headers={'CF-Access-Client-Id': creds['client-id'],
                 'CF-Access-Client-Secret': creds['client-secret']})

    result_json = result.json()

    # Output file
    # output_file_name = f"{output_dir}/lbl_hr_feed.csv"
    # output_dict_list_to_csv()
    output_json_to_csv(result_json, 'lbl_hr_feed.csv')


# ----------------------------------------
def get_reporting_db_data():

    conn = ucpms_db.get_connection(env='prod')

    github_sql_files = [
        {"name": "User_Pub_Relationships.sql"},
        {"name": "Unclaimed_Publication_Metadata.sql"},
        {"name": "Publication_Metadata.sql"}]

    github_raw_link = "https://raw.githubusercontent.com/eScholarship/lbl-get-tableau-data/main/sql_queries/"

    for item in github_sql_files:

        # Get the .sql file data from GitHub
        query_file = item['name']
        print("Querying:", query_file)
        response = requests.get(f"{github_raw_link}/{query_file}")
        sql_query = response.text

        # Open a cursor, send the query.
        with conn.cursor() as cursor:
            cursor.execute(sql_query)
            rows = ucpms_db.get_dict_list(cursor)

            # Output file
            output_file = query_file.replace(".sql", ".csv")
            output_dict_list_to_csv(
                dict_list=rows,
                output_file_path=f"{output_dir}/{output_file}")

    conn.close()


# ----------------------------------------
def export_osti_fy_data():
    print("Exporting/converting OSTI files")

    # Get the OSTI files, filter for any non-xlsx
    osti_files = os.listdir("input_osti_xlsx_files")
    osti_files = [file for file in osti_files if ".xlsx" in file]

    for osti_file in osti_files:
        wb = openpyxl.load_workbook("osti_files/" + osti_file)
        print(wb.sheetnames)

        if 'LBNL' not in wb.sheetnames:
            print("ERROR! There is no 'LBNL' sheet in the OSTI workbook.")
            exit(1)

        # Load the LBNL sheet, convert data to list
        lbnl_sheet = wb['LBNL']
        sheet_data = list(lbnl_sheet.rows)

        # Convert to list to an array of JSON
        sheet_json = []
        column_names = [column.value for column in sheet_data[0]]
        for row in sheet_data[1:]:
            values = [cell.value for cell in row]
            row_dict = {name: str(value) for name, value in zip(column_names, values)}
            sheet_json.append(row_dict)

        # Output file
        output_file_name = (osti_file.split(" - ")[0] + ".csv").lower()
        output_dict_list_to_csv(
            dict_list=sheet_json,
            output_file_path=f"{output_dir}/{output_file_name}")


# ----------------------------------------
def transfer_to_google_drive():

    # import google drive packages
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaIoBaseDownload

    # If modifying these scopes, you need to create a new token.json.
    g_scopes = ["https://www.googleapis.com/auth/drive"]

    # This token needs to be refreshed annually.
    if os.path.exists("token.json"):
        g_creds = Credentials.from_authorized_user_file("token.json", g_scopes)
    else:
        log("ERROR", __name__,
            "No token.json found in this directory. Cannot connect to google drive.")

    try:
        # Create the Google Drive API service
        service = build("drive", "v3", credentials=g_creds)

        # Collect the files to load and reformat as dicts
        files_to_upload = [
            "lbl_hr_feed.csv",
            "Publication_Metadata.csv",
            "Unclaimed_Publication_Metadata.csv",
            "User_Pub_Relationships.csv"]

        if args.process_osti_fy_files:
            files_to_upload.append(["fy2022.csv", "fy2023.csv", "fy2024.csv"])

        files_to_upload = [{'name': filename, 'id': None}
                           for filename in files_to_upload]

        # Get the LBL Tableau folder ID
        param_req = {
            "lbl_g_drive": {
                "folder": "pub-oapi-tools/google-drive",
                "names": ['lbl-tableau-folder-id']
            }
        }
        params = aws_lambda.get_parameters(param_req=param_req)
        params = params['lbl_g_drive']

        # Get the file IDs in the g drive tableau data folder
        tableau_data_folder_id = params['lbl-tableau-folder-id']
        parent_folder_query = f"'{tableau_data_folder_id}' in parents"
        results = (
            service.files().list(
                # pageSize=10,
                includeItemsFromAllDrives=True,
                includeTeamDriveItems=True,
                supportsAllDrives=True,
                supportsTeamDrives=True,
                q=parent_folder_query,
                fields="nextPageToken, files(id, name)",
            ).execute()
        )

        # Get the files and print a spot-check
        google_drive_files = results.get("files", [])
        log("INFO", __name__, "G Drive tableau data folder files:")
        pprint(google_drive_files)

        # Assign extant IDs to files for upload
        for g_file in google_drive_files:
            for u_file in files_to_upload:
                if g_file['name'] == u_file['name']:
                    u_file['id'] = g_file['id']

        for upload_file in files_to_upload:
            upload_file_path = f"{output_dir}/{upload_file['name']}"

            # No matching file in the folder, create a new file:
            if upload_file['id'] is None:
                metadata = {
                    'name': upload_file['name'],
                    'mimeType': 'text/csv',
                    'parents': [tableau_data_folder_id]}

                response = service.files().create(
                    body=metadata,
                    media_body=upload_file_path,
                ).execute()

                if response:
                    log("INFO", __name__, f"CREATED NEW FILE: {response}")

            # The file already exists, update it with the new content.
            else:
                response = service.files().update(
                    fileId=upload_file['id'],
                    media_body=upload_file_path,
                ).execute()

                if response:
                    log("INFO", __name__, f"UPDATED FILE: {response}")

    except HttpError as e:
        print(f"An HTTP error occurred: {e}")


# ----------------------------------------
if __name__ == '__main__':
    main()
