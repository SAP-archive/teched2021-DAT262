# Getting Started

In this exercise, you will...

## Base Data & Demo Scenario<a name="subex1"></a>

In this ...

##  Spatial and Graph Visualizations<a name="subex2"></a>

In this ...

##  Background Material<a name="subex3"></a>

In this ...

1.	Click here.
<br>![](/exercises/ex0/images/00_00_0010.png)

2.	Insert this code.
``` abap
 DATA(params) = request->get_form_fields(  ).
 READ TABLE params REFERENCE INTO DATA(param) WITH KEY name = 'cmd'.
  IF sy-subrc <> 0.
    response->set_status( i_code = 400
                     i_reason = 'Bad request').
    RETURN.
  ENDIF.
```

## Summary

Now that you have ...
Continue to - [Exercise 1 - Preparing the Data](../ex1/README.md)
