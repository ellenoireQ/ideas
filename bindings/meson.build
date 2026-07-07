fs = import('fs')

# Checking the folder is exist or no.
if fs.is_dir('valamark')
  subdir('valamark')
else
  error(
    'The folder does not exist. You need to run git submodule update --init --recursive !',
  )
endif
