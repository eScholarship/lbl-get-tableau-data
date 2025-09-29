import pymssql
import pyodbc
import os
import csv
from dotenv import dotenv_values
from datetime import datetime
import requests


sql_dicts = [
    {"input": "2025_create_temp_tables.sql", "output": False},
    {"input": "2025_grant_metadata.sql", "output": True},
    {"input": "2025_pub_metadata.sql", "output": True},
    {"input": "2025_user_pub_relationships.sql", "output": True}]

creds = dotenv_values()


# ----------------------------------------
def output_json_to_csv(json_array, output_dir, output_file_name):
    with open(output_dir + "/" + output_file_name, 'w') as csv_file:
        csv_writer = csv.writer(csv_file)
        csv_writer.writerow(json_array[0].keys())
        for row in json_array:
            csv_writer.writerow(row.values())


def get_lbl_hr_feed():
    print("Connecting to LBL's API and downloading HR feed.")

    # Send the req, convert results to JSON
    result = requests.get(
        creds['LBL_API_ENDPOINT'],
        headers={
            'CF-Access-Client-Id': creds['LBL_API_HEADER_CLIENT_ID'],
            'CF-Access-Client-Secret': creds['LBL_API_HEADER_CLIENT_SECRET']})

    result_json = result.json()
    return result_json


def get_reporting_db_data(creds, sql_dicts, output_dir):
    print("Connecting to reporting DB...")

    # Connect to Elements Reporting DB
    conn = pyodbc.connect(
        driver=creds['ELEMENTS_REPORTING_DB_DRIVER'],
        server=(creds['ELEMENTS_REPORTING_DB_SERVER'] + ',' + creds['ELEMENTS_REPORTING_DB_PORT']),
        database=creds['ELEMENTS_REPORTING_DB_DATABASE'],
        uid=creds['ELEMENTS_REPORTING_DB_USER'],
        pwd=creds['ELEMENTS_REPORTING_DB_PASSWORD'],
        trustservercertificate='yes',
        autocommit=True)

    cursor = conn.cursor()

    for item in sql_dicts:
        print(f"Querying: {item['input']}")
        sql_query = (open(f"sql_queries/{item['input']}")).read()
        cursor.execute(sql_query)

        # Output file
        if item['output']:
            # pyodbc doesn't have a dict-cursor option, have to do it manually
            columns = [column[0] for column in cursor.description]
            json_array = [dict(zip(columns, row)) for row in cursor.fetchall()]

            output_file = item['input'].replace(".sql", ".csv")
            output_json_to_csv(json_array, output_dir, output_file)

    cursor.close()
    conn.close()


# ------------------------
# Create output dir
output_dir = 'output/' + datetime.today().strftime('%Y-%m-%d-%H-%M-%S')
os.mkdir(output_dir)

# Connect to LBL's HR feed API and download 1 file
hr_feed_json = get_lbl_hr_feed()
output_json_to_csv(hr_feed_json, output_dir, 'lbl_hr_feed.csv')

# Connect to the reporting DB and download 3 files
get_reporting_db_data(creds, sql_dicts, output_dir)

print("Program complete. Exiting.")
