# 事务

🟢**事务是一个数据库操作序列, 这些操作要么全做，要么全不做， 是一个不可分割的工作单元**

🟢**事务用于并发控制和数据恢复**

```sql
> begin transaction;
> rollback;
> commit;
```

## ACID特性

1. 原子性: 操作要么都做, 要么都不做
2. 一致性: 数据库中，只包含成功事务提交的结果
3. 隔离性: 事务间操作不互相干扰
4. 持续性/永久性: 事务提交, 结果永久保存 

## 隔离级别

| 隔离级别         | 脏读 | 不可重复读 | 幻读 |
| ---------------- | ---- | ---------- | ---- |
| READ UNCOMMITTED | ✅    | ✅          | ✅    |
| READ COMMITTED   | ❌    | ✅          | ✅    |
| REPEATABLE READ  | ❌    | ❌          | ✅    |
| SERIALIZABLE     | ❌    | ❌          | ❌    |

```sql
SET [GLOBAL | SESSION] TRANSACTION
    transaction_characteristic [, transaction_characteristic] ...

transaction_characteristic: {
    ISOLATION LEVEL level
  | access_mode
}

level: {
     REPEATABLE READ
   | READ COMMITTED
   | READ UNCOMMITTED
   | SERIALIZABLE
}

access_mode: {
     READ WRITE
   | READ ONLY
}

-- 全局事务隔离级别、访问模式
SELECT @@GLOBAL.transaction_isolation;
SELECT @@GLOBAL.transaction_read_only;

-- session级事务隔离级别、访问模式
SELECT @@SESSION.transaction_isolation;
SELECT @@SESSION.transaction_read_only;

-- MySQL默认隔离级别: repeatable read
```

### 读未提交

🟢还没提交，就读到了  (脏)

```sql
mysql> set transaction isolation level read uncommitted;
Query OK, 0 rows affected (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行如下SQL
					# > begin;
					# > insert into transaction_test value (1, '读未提交');

mysql> select * from transaction_test;
+------+--------------+
| id   | message      |
+------+--------------+
|    1 | 读未提交     |
+------+--------------+
1 row in set (0.00 sec)

					# -- 另一事务回滚
					# > rollback

mysql> select * from transaction_test;
Empty set (0.00 sec)

mysql> commit;
Query OK, 0 rows affected (0.00 sec)
```

### 读已提交

🟢提交了，才能读

```sql
mysql> set transaction isolation level read committed;
Query OK, 0 rows affected (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行如下SQL
					# > begin;
					# > insert transaction_test values (1, '读已提交');

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务提交
					# > commit;

mysql> select * from transaction_test;
+------+--------------+
| id   | message      |
+------+--------------+
|    1 | 读已提交     |
+------+--------------+
1 row in set (0.00 sec)

mysql> commit;
Query OK, 0 rows affected (0.00 sec)
```

### 可重复读

🟢提交了，也读不到

```sql
mysql> set transaction isolation level REPEATABLE READ;
Query OK, 0 rows affected (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.07 sec)

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行如下SQL
					# > begin;
					# > insert transaction_test values (1, '可重复读');
					# > commit;

mysql> select * from transaction_test;
Empty set (0.00 sec)

mysql> commit;
Query OK, 0 rows affected (0.00 sec)
```

🟢没读到, 但能改 (幻)

```sql
mysql> set transaction isolation level REPEATABLE READ;
Query OK, 0 rows affected (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.07 sec)

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行如下SQL
					# > begin;
					# > insert transaction_test values (1, '幻读');
					# > commit;

mysql> select * from transaction_test;
Empty set (0.00 sec)

mysql> update transaction_test set message='幻读' where id = 1;
Query OK, 0 rows affected (0.00 sec)
Rows matched: 1  Changed: 0  Warnings: 0

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行如下SQL, 操作挂起！
					# > delete from transaction_test where id = 1;
					# ^C^C -- query aborted
					# ERROR 1317 (70100): Query execution was interrupted

mysql> commit;
Query OK, 0 rows affected (0.00 sec)
```

如果改动成功了, 可以读取到...

```sql
mysql> set transaction isolation level REPEATABLE READ;
Query OK, 0 rows affected (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.07 sec)

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行如下SQL
					# > begin;
					# > insert transaction_test values (1, '幻读');
					# > commit;

mysql> select * from transaction_test;
Empty set (0.00 sec)

mysql> update transaction_test set message='读已提交' where id = 1;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> select * from transaction_test;
+------+--------------+
| id   | message      |
+------+--------------+
|    1 | 读已提交     |
+------+--------------+
1 row in set (0.00 sec)

					# -- 另一事务中, 执行如下SQL, 操作挂起！
					# > delete from transaction_test where id = 1;
					# ^C^C -- query aborted
					# ERROR 1317 (70100): Query execution was interrupted

mysql> commit;
Query OK, 0 rows affected (0.00 sec)
```

### 序列化读

```sql
mysql> set transaction isolation level serializable;
Query OK, 0 rows affected (0.00 sec)

mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from transaction_test;
Empty set (0.00 sec)

					# -- 另一事务中, 执行插入语句, 操作挂起
					# > begin;
					# > insert into transaction_test value (1, '序列化');
					# 挂起可能会超时: Lock wait timeout exceeded;

mysql> commit;
Query OK, 0 rows affected (0.00 sec)
```

## 保存点


```sql
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into transaction_test value (1, 'Hello, MySQL');
Query OK, 1 row affected (0.00 sec)

mysql> savepoint sp1;
Query OK, 0 rows affected (0.00 sec)

mysql> insert into transaction_test value (2, 'Hello, MySQL');
Query OK, 1 row affected (0.00 sec)

mysql> select * from transaction_test;
+------+--------------+
| id   | message      |
+------+--------------+
|    1 | Hello, MySQL |
|    2 | Hello, MySQL |
+------+--------------+
2 rows in set (0.00 sec)

mysql> rollback to sp1;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from transaction_test;
+------+--------------+
| id   | message      |
+------+--------------+
|    1 | Hello, MySQL |
+------+--------------+
1 row in set (0.00 sec)

mysql> commit;
Query OK, 0 rows affected (0.10 sec)
```

## MySQL官方文档

[事务设置](https://dev.mysql.com/doc/refman/8.0/en/set-transaction.html)