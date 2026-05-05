import pymysql

def get_conn():
    return pymysql.connect(
        host="localhost",
        user="root",
        password="123456",
        database="portfolio",
        charset="utf8mb4"
    )
