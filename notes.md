```sql
with recursive neighbors_cte as (
  select e.source, e.target, p.recent_downloads, 1 as distance
    from packages_edges e
    join packages p on e.target = p.name
    where e.source = ? and p.recent_downloads > 10000
  union
  select n.source, e.target, p.recent_downloads, n.distance + 1
    from neighbors_cte n
    join packages_edges e on n.target = e.source
    join packages p on e.target = p.name
    where n.distance <= 2 and p.recent_downloads > pow(10, n.distance + 4)
), neighbors as (
  select n.target as package, min(n.distance) as distance, min(n.recent_downloads) as recent_downloads
    from neighbors_cte n
    group by n.target
)
select
  d.id,
  d.package,
  d.ref,
  d.title,
  a.rank,
  p.recent_downloads,
  n.distance,
  round(a.rank / 2) as score1,
  p.recent_downloads / coalesce(n.distance, 5) as score2
from docs d
  inner join autocomplete a on d.id = a.rowid
  inner join packages p on d.package = p.name and p.recent_downloads > 1000
  left join neighbors n on d.package = n.package
where a.title match ?
order by score1, score2 desc
limit 10;

with recursive neighbors_cte as (
  select e.source, e.target, p.recent_downloads, 1 as distance
    from packages_edges e
    join packages p on e.target = p.name
    where e.source = ? and p.recent_downloads > 10000
  union
  select n.source, e.target, p.recent_downloads, n.distance + 1
    from neighbors_cte n
    join packages_edges e on n.target = e.source
    join packages p on e.target = p.name
    where n.distance <= 2 and p.recent_downloads > pow(10, n.distance + 4)
), neighbors as (
  select n.target as package, min(n.distance) as distance, min(n.recent_downloads) as recent_downloads
    from neighbors_cte n
    group by n.target
)
select
  d.id,
  d.package,
  d.ref,
  d.title,
  a.rank,
  p.recent_downloads,
  n.distance,
  round(a.rank / 2),
  p.recent_downloads / 2000000 * coalesce(n.distance, 1) as score2
from docs d
  inner join autocomplete a on d.id = a.rowid
  inner join packages p on d.package = p.name and p.recent_downloads > 1000
l eft join neighbors n on d.package = n.package
where a.title match ?
order by rank
limit 10;
```
