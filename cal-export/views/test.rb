get '/' do
  haml :index
end

use_in_file_templates!

__END__

@@ layout
X
= yield
X

@@ index
%div.title Hello world!!!!!