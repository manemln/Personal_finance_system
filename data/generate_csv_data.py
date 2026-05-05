import csv, random, datetime
from pathlib import Path
out = Path(__file__).resolve().parents[1] / 'data'
out.mkdir(exist_ok=True)
random.seed(42)
with open(out/'users.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['user_id','full_name','email','role'])
    for i in range(1,1001):
        role='admin' if i<=20 else 'stakeholder' if i<=80 else 'user'
        w.writerow([i,f'User {i}',f'user{i}@financehub.test',role])
with open(out/'transactions.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['txn_id','account_id','category_id','merchant_id','txn_date','description','amount'])
    start=datetime.date(2025,1,1)
    for i in range(1,12001):
        income = i % 5 == 0
        w.writerow([i,(i%2000)+1,1 if income else 5+(i%10),'' if income else (i%1000)+1,start+datetime.timedelta(days=i%365),'Monthly income' if income else 'Daily expense',2500+(i%900) if income else -1*(10+(i%250))])
print('CSV data generated in', out)
