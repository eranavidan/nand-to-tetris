my $file = '(xxx+12)*-63;';

$KEYWORD = 'class|constructor|function|method|field|static|var|int|char|boolean|void|true|false|null|this|let|do|if|else|while|return';
$SYMBOL = '{|}|\(|\)|\[|\]|\.|,|;|\+|\-|\*|\/|\&|\||<|>|=|~';
$INT_CONST = '\d+';
$STRING_CONST = '"[^\n"]+"';
$IDENTIFIER = '[a-zA-Z0-9_]+';




$varName = $subroutineName = $className = $IDENTIFIER;
$type = 'int|char|boolean|$className';
$class = 'class\s+$className\s*\{\s*$classVarDec*\s*$subroutineDec*\\s*}';
$classVarDec = '(static|field)\s+$type\s+$varName\s*(,$varName)*\s*;';
$subroutineDec = '(constructor|function|method)\s+(void|$type)\s+$subroutineName\s*\(\s*$parameterList\s*\)\s*$subroutineBody';
$parameterList = '(($type\s*$varName)(\s*,\s*$type\s*$varName)*)?';
$subroutineBody = '{\s*$varDec*\s*$statements\s*}';
$varDec = 'var\s+$type\s+$varName\s+(,varName)*\s*;';  

$returnStatement = 'return\s*$expression?;';
$doStatement = 'do\s*$subroutineCall;';
$whileStatement = 'while\s*\($expression\)\s*{$statements}';
$ifStatement = 'if\s*\($expression\)\s*{$statements}\s*(else\s*{\s*$statements\s*}\s*)?';
$letStatement = 'let\s*$varName(\[$expression\])?=$expression;';
$statement = '$letStatement|$ifStatement|$whileStatement|$doStatement|$returnStatement';
$statements = '$statement*';

$KeywordConstant = 'true|false|null|this';
$unaryOp = '-|~';
$oper = '\+|\-|\*|\/|\&|\||<|>|=';
$expression = '$term\s*($oper\s*$term\s*)*';
$expressionList = '($expression(\s*,\s*$expression)*)?';
$subroutineCall = '$subroutineName\s*\($expressionList\)|($className|$varName)\s+$subroutineName\s*\(\s*$expressionList\s*\)'; 
$term = '$INT_CONST|$STRING_CONST|$KeywordConstant|$varName|$varName\[$expression\]|$subroutineCall|\($expression\)|$unaryOp $term';

open (FH,'>regex.txt');
$x = '(3|5|$y)';
$y = '($x\+4)';
$tmp = '$x\+$y';
$str = "3+3+4";
print FH "$tmp\n";

$tmp =~ s/\$(\w+)/${$1}/g;

print FH "$tmp\n";
$tmp =~ s/\$(\w+)/${$1}/g;
print FH  "$tmp\n";
$tmp =~ s/\$(\w+)/${$1}/g;
print FH  "$tmp\n";


exit;



my $cnt = 1;

$tmp = $expression;
#$file = "<subroutineDec>$file<\/subroutineDec>";
#$tmp =~ s/(\$unaryOp|\$op|\$INT_CONST|\$STRING_CONST|\$KeywordConstant)/${$1}/g;
#$tmp =~ s/\$op/$op/g;
print FH "$tmp\n";
$file =~ /(.*)$oper(.*)/;
print FH "$1\n";
print FH "$2\n";
exit;


while ($tmp =~ s/\$(\w+)/${$1}/g && $cnt++<4) {print FH "$tmp\n\n";};
#if ($file =~ /$tmp/;
print "$1\n";
print FH "$tmp\n";
$tmp =~ s/\$(\w+)/${$1}/;
print FH "$tmp\n";

#$tmp =~ s/(\$\w+)/\[$1]/g;
close(FH);
exit;


while ($tmp =~ s/\$(\w+)/${$1}/g) {
	$tmp =~ s/(\$unaryOp|\$op|\$INT_CONST|\$STRING_CONST|\$KeywordConstant)/${$1}/g;
	$empty = $tmp;
	$empty =~ s/\$(\w+)(\*)?/\.*/g;
	print FH "$tmp\n";
	print FH "$empty\n";
	$frame = $1;
	print "$frame\n";
	$file =~ s/($empty)/<$frame>${$1}<\/$frame>/g;
	print "$1\n";
	#print FH "$1\n";
	print FH "$file\n";
	#print FH "$tmp\n";
	if ($cnt++ > 10){
		exit;
	};
	
} 

#$file =~ /$tmp/

print FH $tmp;
close (FH);
exit;

my $rr = \&comp;
$file =~ s/(constructor|function|method)\s(\w+)\s*(\w+)\(/&CompileSubroutine($2,$3)/eg;
print $file;
sub CompileSubroutine(){
	($x,$y) = @_;
	return ex($x) . ex($y);
}

sub ex(){
	my $s = shift;
	return "<>$s</>\n";
}

#$token
#while ($file =~ s/^class|constructor|function|method|field|static|var|int|char|boolean|void|true|false|null|this|let|do|if|else|while|return/KEYWORD/g){};
#while ($file =~ s/{|}|\(|\)|\[|\]|\.|,|;|\+|\-|\*|\/|\&|\||<|>|=|~/SYMBOL/g){};
#while ($file =~ s/\d+/INT_CONST/g){};
#while ($file =~ s/[^0-9][a-zA-Z0-9_]+/IDENTIFIER/g){};
#print $file;
