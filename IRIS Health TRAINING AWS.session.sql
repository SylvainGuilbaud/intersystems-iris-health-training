select 
id
,uid
,timestamp
,document
,substr(embedding,1,100) 
,metadata
,username
from Demo_Vector.Document