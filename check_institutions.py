import pandas as pd

df = pd.read_csv('raw_directory.csv')
cols = ['unitid', 'year', 'sector', 'currently_active_ipeds']
for col in cols:
    print(f'--- {col} ---')
    print('dtype:', df[col].dtype)
    print('min:', df[col].min(), 'max:', df[col].max())
    print('sample unique values:', df[col].unique()[:10])
    print()