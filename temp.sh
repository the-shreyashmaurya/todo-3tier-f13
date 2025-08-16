echo 'DATABASE_URL=mysql+pymysql://appuser:ChangeMe!123@todo3tier-default-mysql-primary.cro088wagfps.ap-south-1.rds.amazonaws.com:3306/todo_db' | sudo tee /etc/todo.env
sudo chmod 640 /etc/todo.env
sudo chown root:root /etc/todo.env