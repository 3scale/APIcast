# Liquid conditions examples

You can use Liquid to configure conditions applicable across multiple policies to <insert_purpose>
of conditions that can be used across multiple policies


## Headers

### Header is not present

Condition passes if the  'Backend' header is sent and it's staging

```
"condition":{
   "operations":[
      {
         "left":" {% if headers['Backend'] %}{{ headers['Backend'] }}{%else%}Notpresent{%endif%}",
         "left_type":"liquid",
         "op":"==",
         "right":"staging"
      }
   ]
}
```

If you want to test when the `Backend` header is not present, the condition is as follows:

```
"condition":{
   "operations":[
      {
         "left":" {% if headers['Backend'] %}IsPresent{%else%}Notpresent{%endif%}",
         "left_type":"liquid",
         "op":"==",
         "right":"Notpresent"
      }
   ]
}
```

## Numeric operations

Numeric operations require additional steps. By default, all the values on liquid are strings, so you need
to get any integer before do any operation. Use `minus` or `plus`
filters along with `0` (zero), and apply the following configuration:


```
"condition":{
  "operations":[
    {
      "left": "{% assign val = headers['version'] | minus:0 %} {%if val < 20 %}PASS{%else%}DENIED{%endif%}",
      "left_type":"liquid",
      "op":"==",
      "right":"PASS"
    }
 ]
}
```

@TODO: something like a int filter should be added.
@TODO: default filter should be added too.


## Additional examples:

[How to send different headers according to the Application Plan](https://access.redhat.com/solutions/3925031)
