# Liquid conditions examples

When using liquid, a lot of things can be achieved, and here are some examples
of conditions that can be used across multiple policies


## Headers

### Header is not present

Condition pass if header 'Backend' is sent and it's staging

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

If want to test when the header is not present, the condition will be like this:

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

These are harder, by default, all the values on liquid are strings, so we need
to get any integer before do any operation. We can use `minus` or `plus`
filters using 0, and do something like this:


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


## Another examples:

[How to send different headers according to the Application Plan](https://access.redhat.com/solutions/3925031)
