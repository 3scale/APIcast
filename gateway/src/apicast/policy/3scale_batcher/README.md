# 3scale Batcher Policy

## Description

The APIcast policy performs one call to the 3scale backend for each request that
it receives. The goal of this policy is to reduce latency and increase
throughput by significantly reducing the number of requests made to the 3scale
backend. In order to achieve that, this policy caches authorization statuses and
batches reports.

## Technical details

When the APIcast policy receives a request, it makes an 'authrep' call to
backend. This call checks the credentials sent by APIcast, and also applies rate
limiting over the metrics sent by APIcast. If the credentials are correct and
rate limits not violated, backend also increases the counters of the metrics
reported by APIcast. This counters are used both to show statistics in the
3scale UI and also to apply the rate limits. This means that the rate limiting
applied will not be accurate until the counter is updated. For limits defined
for long windows of time (hour, day, etc.) this update lag if often irrelevant.
However, it might be important to take it into account for limits defined for a
small window of time (a per-minute limit, for example).

This policy uses a cache for authorizations and batches reports. Also, it makes
'authorize' and 'report' calls to backend instead of 'authrep' calls. On each
request, the flow is as follows:

1. The policy checks whether the credentials are cached. If they are, the policy
uses the cached authorization status instead of calling 3scale's backend. When
the credentials are not cached, it calls backend and caches the authorization
status with a configurable TTL.

2. Instead of reporting to 3scale's backend the metrics associated with the
request, the policy accumulates their usages to report to backend in batches.

Apart from that, there's a separate thread that reports to backend periodically.
The time is configurable. This thread fetches all the batched reports and sends
them to backend in a single call.

This approach increases throughput for two reasons. First, it caches
authorizations. This reduces the number of calls to the 3scale backend. Second,
it batches the reports. This also helps reducing the number of calls made to the
3scale backend, but more importantly, it also reduces the amount of work it
needs to do because the policy already aggregated the metrics to report. Suppose
that we define a mapping rule that increases the metric 'hits' by one on each
request. Suppose also that we have 1000 requests per second. If we define a
batching period of 10 seconds, this policy will report to 3scale backend just a
'hits +10000' instead of 10000 separated 'hits +1'. This is very important,
because from the 3scale backend perspective reporting a +10000 or a +1 to its
database it's the same amount of work.

Of course, reporting to 3scale in batches has a trade-off. Rate limiting loses
accuracy. The reason is that while reports are accumulated, they're not being
sent to backend and rate limits only take into account reports that have been
stored in the 3scale backend database. In summary, going over the defined usage
limits is easier. The APIcast policy reports to 3scale backend every time it
receives a request. Reports are asynchronous and that means that we can go over
the limits for a brief window of time. On the other hand, this policy reports
every X seconds (configurable) to 3scale backend. The window of time in which we
can get over the limits is wider in this case.

The effectiveness of this policy will depend on the cache hit ratio. For use
cases where the variety of services, apps, metrics, etc. is relatively low,
caching and batching will be very effective and will increase the throughput of
the system significantly.

### How many key/value pairs can be contained in 20m of shared memory.

On my Linux x86_64 system `1m` can hold `4033 key/value pairs` with 64-byte keys and
15-byte values. Changing the size of the shared storage to 10m gives `40673 key/value pairs`.
It's a linear growth as expected.

The following table shows the number of key/value pairs for different storage size:

| Shared storage size | Key length | Value length | Key/value pairs |
| ---- | ---- | ---- | ---- |
| 10m | 64 | 15 | 40672 |
|  | 128 | 15 | 40672 |
|  | 256 | 15 | 20336 |
|  | 512 | 15 | 10168 |
| 20m | 64 | 15 | 81408 |
|  | 128 | 15 | 81408 |
|  | 256 | 15 | 40704 |
|  | 512 | 15 | 20352 |
| 40m | 64 | 15 | 162848 |
|  | 128 | 15 | 162848 |
|  | 256 | 15 | 81424 |
|  | 512 | 15 | 40712 |

In practice, the actual number will depend on the size of the key/value pair, the
underlying OS architecture, memory segment sizes, etc... More details [here](https://blog.openresty.com/en/nginx-shm-frag/)
