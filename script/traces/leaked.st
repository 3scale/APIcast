BEGIN {
  printf("Probe started\n");
}

uretprobe:/usr/local/openresty/nginx/sbin/nginx:ngx_create_pool {
  @pools[retval] = ustack ;
}

uprobe:/usr/local/openresty/nginx/sbin/nginx:ngx_destroy_pool {
  delete(@pools[arg0]);
}

interval:s:60 {
  printf("--------------\n");
  print(@pools);
}
