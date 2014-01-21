import multiprocessing


bind = '0.0.0.0:8000'
django_settings = 'deis.settings'
workers = multiprocessing.cpu_count() * 2 + 1
