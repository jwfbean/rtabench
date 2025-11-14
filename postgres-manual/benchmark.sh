#!/bin/bash

export CONNECTION_STRING=YOUR_STRING_HERE

sudo apt-get update

#Download the dataset
wget --no-verbose --continue 'https://rtadatasets.timescale.com/customers.csv.gz'
wget --no-verbose --continue 'https://rtadatasets.timescale.com/products.csv.gz'
wget --no-verbose --continue 'https://rtadatasets.timescale.com/orders.csv.gz'
wget --no-verbose --continue 'https://rtadatasets.timescale.com/order_items.csv.gz'
wget --no-verbose --continue 'https://rtadatasets.timescale.com/order_events.csv.gz'
gzip -d customers.csv.gz products.csv.gz orders.csv.gz order_items.csv.gz order_events.csv.gz
sudo chmod og+rX ~
chmod 777 customers.csv products.csv orders.csv order_items.csv order_events.csv
mkdir -p dataset
mv *.csv dataset/

sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

sudo apt-get update
sudo apt install -y postgresql-client-17

# Import the data
psql "$CONNECTION_STRING" < create.sql #import

psql "$CONNECTION_STRING" -t -c '\timing' -c "\\COPY customers FROM 'dataset/customers.csv' WITH (FORMAT csv);" #import
psql "$CONNECTION_STRING" -t -c '\timing' -c "\\COPY products FROM 'dataset/products.csv' WITH (FORMAT csv);" #import
psql "$CONNECTION_STRING" -t -c '\timing' -c "\\COPY orders FROM 'dataset/orders.csv' WITH (FORMAT csv);" #import
psql "$CONNECTION_STRING" -t -c '\timing' -c "\\COPY order_items FROM 'dataset/order_items.csv' WITH (FORMAT csv);" #import
psql "$CONNECTION_STRING" -t -c '\timing' -c "\\COPY order_events FROM 'dataset/order_events.csv' WITH (FORMAT csv);" #import

psql "$CONNECTION_STRING" -t -c '\timing' -c "CREATE INDEX orders_customer_id_index ON orders (customer_id);"
psql "$CONNECTION_STRING" -t -c '\timing' -c "CREATE INDEX order_events_order_id_index ON order_events (order_id);"
psql "$CONNECTION_STRING" -t -c '\timing' -c "CREATE INDEX order_events_event_type_index ON order_events (event_type);"

psql "$CONNECTION_STRING" -c "\t" -c "SELECT pg_total_relation_size('order_events') + pg_total_relation_size('orders') + pg_total_relation_size('order_items') + pg_total_relation_size('products') + pg_total_relation_size('customers') + pg_indexes_size('order_events') + pg_indexes_size('orders') + pg_indexes_size('customers') + pg_indexes_size('products') + pg_indexes_size('order_items');" #datasize

./run.sh 2>&1 | tee log.txt

cat log.txt | grep -oP 'Time: \d+\.\d+ ms' | sed -r -e 's/Time: ([0-9]+\.[0-9]+) ms/\1/' |
  awk '{ if (i % 3 == 0) { printf "[" }; printf $1 / 1000; if (i % 3 != 2) { printf "," } else { print "]," }; ++i; }'  #results

echo "General Purpose" #tag
echo "Postgres" #name
