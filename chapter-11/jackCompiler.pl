use Cwd 'abs_path';

# when passing arg from bash last char needs to be dropped
my $t = $ARGV[0] || '';
$t =~ s/[^\w]$//;
my $abs_path = abs_path();
$abs_path = abs_path($t) if $t!~/^$/;

die 'Usage: JackAnalyzer.pl [ <file> | <directory> ]' unless $abs_path;

our $whileIndex = 0;
our $ifIndex = 0;
our $keyword = 'class|constructor|function|method|field|static|var|int|char|boolean|void|let|true|false|null|this|do|if|else|while|return';
our $symbol = '{|}|\(|\)|\[|\]|\.|,|;|\+|\-|\*|\/|\&|\||<|>|=|~';
our $integerConstant = '\d+';
our $stringConstant = '"[^\n"]+"';
our $identifier = '[a-zA-Z_][a-zA-Z0-9_]*';
our $varName = $subroutineName = $className = $identifier;
our $type = "int|char|boolean|$className";
our $keywordConstant = 'true|false|null|this';
our $unaryOp = '-|~';
our $oper = '\+|\-|\*|\/|\&|\||<|>|=';

package main;
	my $CompilationEngine = CompilationEngine->new;
	$CompilationEngine->init;

	if (-d $abs_path) {
		opendir(my $dh, $abs_path) or die "Unable to open directory $abs_path";
		foreach my $file (grep { -f "$abs_path/$_" && /\.jack$/ } readdir($dh)) {
			$CompilationEngine->init;
			$CompilationEngine->load_file("$abs_path/$file");
			$out_file = "$abs_path/$file";
			$out_file =~ s/\.(\w+)$/\.xml/;
			open (FH, ">$out_file") || die "Unable to open file for writing: $out_file ";
			print FH $CompilationEngine->compile;
			close (FH);
		}	 
		closedir($dh);
	}
	elsif (-f $abs_path) {
		$CompilationEngine->load_file($abs_path);
		$out_file = "$abs_path";
		$out_file =~ s/\.(\w+)$/\.xml/;
		open (FH, ">$out_file") || die "Unable to open file for writing: $out_file ";
		print FH $CompilationEngine->compile;
		close (FH);
	}
	else {
		die 'Fatal: A file or directory must be provided';
	}

package CompilationEngine;
	sub new { return bless {}, shift; }

	sub init {
		my $self = shift;
		$self->{Tokenizer} = Tokenizer->new;
		$self->{VMWriter} = VMWriter->new;
		$self->{SymbolTable} = SymbolTable->new;
	}

	sub load_file {
		my ($self, $file) = @_;

		open(my $fh, '<', $file) or die "Unable to open $file";
		$self->{Tokenizer}->load_file($fh);
		$file =~ s/\.(\w+)$/\.vm/;
		$self->{VMWriter}->init($file);
	}

	sub compile {
		my $self = shift;
		$self->{Tokenizer}->advance;
		return $self->compileClass;
	}
   
	sub compileClass{
		my $self = shift;
		$self->{SymbolTable}->init;
		my $output = "<class>\n";
		warn "$self->{Tokenizer}->{token}. expected class\n" if $self->{Tokenizer}->keyword ne 'CLASS';
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		warn "$self->{Tokenizer}->{token}. expected class name\n" if $self->{Tokenizer}->tokenType ne 'identifier';
		$self->{className} = $self->{Tokenizer}->{token};
		$output .= $self->XMLwrap('identifier',$self->{Tokenizer}->{token});
		$output .= $self->handlesymbol('{');
		$output .= $self->compileClassVarDec while ($self->{Tokenizer}->keyword =~ /STATIC|FIELD/);
		$output .= $self->compileSubroutine while ($self->{Tokenizer}->keyword =~ /CONSTRUCTOR|FUNCTION|METHOD/);		
		$output .= $self->handlesymbol('}');
		$output .= "</class>\n";
		return $output;
	}
	
	sub compileClassVarDec(){
		my $self = shift;
		my $output = "<classVarDec>\n";
		my $varKind = $self->{Tokenizer}->keyword;
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		my $varType = $self->{Tokenizer}->{token};
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		while($self->{Tokenizer}->{token} ne ';'){
			my $name = $self->{Tokenizer}->{token};
			$self->{SymbolTable}->define($name, $varType, $varKind);
			$output .= $self->XMLwrap('identifier',$self->{Tokenizer}->{token});
			$output .= $self->XMLwrap('symbol',$self->{Tokenizer}->{token}) if $self->{Tokenizer}->{token} eq ',';
		}
		$output .= $self->handlesymbol(';');
		$output .= "</classVarDec>\n";
		return $output;
	}
	
	sub compileSubroutine{
		my $self = shift;
		my $output = "<subroutineDec>\n";
		$self->{SymbolTable}->startSubroutine;
		warn "$self->{Tokenizer}->{token}. expected CONSTRUCTOR|FUNCTION|METHOD\n" if $self->{Tokenizer}->keyword !~ /CONSTRUCTOR|FUNCTION|METHOD/;
		my $subType = $self->{Tokenizer}->keyword;
		$output .= $self->XMLwrap('keyword', $self->{Tokenizer}->{token});				
		warn "$self->{Tokenizer}->{token}. expected INT|CHAR|BOOLEAN|VOID|Class\n" if $self->{Tokenizer}->tokenType !~ /VOID|$type/;
		$output .= $self->XMLwrap('identifier', $self->{Tokenizer}->{token});				
		warn "$self->{Tokenizer}->{token}. expected sub name\n" if $self->{Tokenizer}->tokenType !~ /$subroutineName/;
		my $name = $self->{Tokenizer}->{token};
		$self->{SymbolTable}->define('this', $self->{className}, 'ARGUMENT') if $subType =~ /METHOD/;	
		$self->{SymbolTable}->define('this', $self->{className}, 'POINTER') if $subType =~ /CONSTRUCTOR|METHOD/;	
		$output .= $self->XMLwrap('identifier', $self->{Tokenizer}->{token});
		$output .= $self->handlesymbol('(');	
		$output .= $self->compileParameterList;
		$output .= $self->handlesymbol(')');
		$output .= "<subroutineBody>\n";
		$output .= $self->handlesymbol('{');
		$output .= $self->compileVarDec while ($self->{Tokenizer}->keyword =~ /VAR/);
		my $localCnt = $self->{SymbolTable}->varCount('VAR');
		$self->{VMWriter}->writeFunction("$self->{className}\.$name", $localCnt);
		if ($subType =~ /METHOD/){
			$self->{VMWriter}->writePush('argument', 0);
			$self->{VMWriter}->writePop('pointer', 0);
		}
		if ($subType =~ /CONSTRUCTOR/){
			$self->{VMWriter}->writePush('constant', $self->{SymbolTable}->varCount('FIELD'));
			$self->{VMWriter}->writeCall('Memory.alloc', 1);
			$self->{VMWriter}->writePop('pointer', 0);
		}
		$output .= $self->compileStatements;		
		$output .= $self->handlesymbol('}');
		$output .= "</subroutineBody>\n";
		$output .= "</subroutineDec>\n";
		#$self->{SymbolTable}->printMethodTable;
		return $output;
	}
	
	sub compileParameterList{
		my $self = shift;
		my $output = "<parameterList>\n";
		while ($self->{Tokenizer}->{token} ne ')'){
			my $type = $self->{Tokenizer}->{token};
			$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
			my $name = $self->{Tokenizer}->{token};
			$self->{SymbolTable}->define($name, $type, 'ARGUMENT');
			$output .= $self->XMLwrap('identifier',$self->{Tokenizer}->{token});
			warn "expected ')'\n" if $self->{Tokenizer}->{token} !~ /^,|\)$/;
			$output .= $self->handlesymbol(',') if $self->{Tokenizer}->{token} eq ',';
		}
		$output .= "</parameterList>\n";
		return $output;		
	}
	
	sub XMLwrap(){
		my $self = shift;
		my $tag = shift;
		my $content = shift;
		$content =~ s/"//g;
		$content =~ s/&/&amp;/;
		$content =~ s/</&lt;/;
		$content =~ s/>/&gt;/;
		$content =~ s/"/&quot;/;
		
		$tag = $self->{Tokenizer}->tokenType;
		$self->{Tokenizer}->advance;
		return "<$tag>$content</$tag>\n";
	}
	
	sub compileVarDec{
		my $self = shift;
		my $output = "<varDec>\n";
		warn "expected variable name\n" if $self->{Tokenizer}->{token} !~ /$type/;
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		warn "expected variable type\n" if $self->{Tokenizer}->{token} !~ /$varName/;
		my $varType = $self->{Tokenizer}->{token};
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		while($self->{Tokenizer}->{token} ne ';'){
			warn "expected variable name\n" if $self->{Tokenizer}->{token} !~ /$varName/;
			my $name = $self->{Tokenizer}->{token};
			$self->{SymbolTable}->define($name, $varType, 'VAR');
			$output .= $self->XMLwrap('identifier',$self->{Tokenizer}->{token});
			$output .= $self->handlesymbol(',') if $self->{Tokenizer}->{token} eq ',';
		}
		$output .= $self->handlesymbol(';');
		$output .= "</varDec>\n";
		return $output;
	}
	
	sub compileStatements{
		my $self = shift;
		my $output = "<statements>\n";
		while ($self->{Tokenizer}->keyword =~ /LET|DO|IF|WHILE|RETURN/)
		{
			$output .= $self->compileLet if $self->{Tokenizer}->keyword eq 'LET'; 
			$output .= $self->compileIf if $self->{Tokenizer}->keyword eq 'IF';
			$output .= $self->compileWhile if $self->{Tokenizer}->keyword eq 'WHILE';
			$output .= $self->compileDo if $self->{Tokenizer}->keyword eq 'DO';
			$output .= $self->compileReturn if $self->{Tokenizer}->keyword eq 'RETURN';
		}
		$output .= "</statements>\n";
		return $output;
	}
	
	sub compileDo(){
		my $self = shift;
		my $output = "<doStatement>\n";
		$output .= $self->XMLwrap('keyword','do');
		$output .= $self->compileSubroutineCall;
		$output .= $self->handlesymbol(';');
		$output .= "</doStatement>\n";
		$self->{VMWriter}->writePop('temp', 0);
		return $output;
	}
	
	sub compileReturn(){
		my $self = shift;
		my $output = "<returnStatement>\n";
		$output .= $self->XMLwrap('keyword','return');
		if ($self->{Tokenizer}->{token} ne ';'){
			$output .= $self->compileExpression;
		}
		else{
			$self->{VMWriter}->writePush('constant', 0);
		}

		$self->{VMWriter}->writeReturn;		
		$output .= $self->handlesymbol(';');		
		$output .= "</returnStatement>\n";
		return $output;
	}
	
	sub compileIf(){
		my $self = shift;
		my $output = "<ifStatement>\n";
		my $i = $ifIndex++;
		my $isElse = 0;
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		$output .= $self->handlesymbol('(');
		$output .= $self->compileExpression;
		$output .= $self->handlesymbol(')');
		$self->{VMWriter}->writeIfGoto('IF_TRUE'.$i);
		$self->{VMWriter}->writeGoto('IF_FALSE'.$i);
		$self->{VMWriter}->writeLabel('IF_TRUE'.$i);
		$output .= $self->handlesymbol('{');
		$output .= $self->compileStatements;
		$output .= $self->handlesymbol('}');
		if ($self->{Tokenizer}->keyword eq 'ELSE'){
			$self->{VMWriter}->writeGoto('IF_END'.$i);
			$isElse = 1;
		}
		$self->{VMWriter}->writeLabel('IF_FALSE'.$i);
		if ($self->{Tokenizer}->keyword eq 'ELSE'){
			$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
			$output .= $self->handlesymbol('{');
			$output .= $self->compileStatements;
			$output .= $self->handlesymbol('}');
		}
		$self->{VMWriter}->writeLabel('IF_END'.$i) if $isElse == 1;
		$output .= "</ifStatement>\n";
		return $output;
	}
	
	sub compileWhile(){
		my $self = shift;
		my $i = $whileIndex++;
		my $output = "<whileStatement>\n";
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		$self->{VMWriter}->writeLabel('WHILE_EXP'.$i);
		$output .= $self->handlesymbol('(');
		$output .= $self->compileExpression;
		$output .= $self->handlesymbol(')');
		$self->{VMWriter}->writeArithmetic('~');
		$self->{VMWriter}->writeIfGoto('WHILE_END'.$i);
		$output .= $self->handlesymbol('{');
		$output .= $self->compileStatements;
		$output .= $self->handlesymbol('}');
		$self->{VMWriter}->writeGoto('WHILE_EXP'.$i);
		$self->{VMWriter}->writeLabel('WHILE_END'.$i);
		$output .= "</whileStatement>\n";
		return $output;
	}
	
	sub compileLet(){
		my $self = shift;
		my $output = "<letStatement>\n";
		$output .= $self->XMLwrap('keyword',$self->{Tokenizer}->{token});
		warn "expected variable name\n" if $self->{Tokenizer}->{token} !~ /$varName/;
		my $name = $self->{Tokenizer}->{token};
		$output .= $self->XMLwrap('identifier',$self->{Tokenizer}->{token});
		if ($self->{Tokenizer}->{token} eq '['){
			$output .= $self->handlesymbol('[');
			$output .= $self->compileExpression;
			$output .= $self->handlesymbol(']');
			$self->{VMWriter}->writePush($self->{SymbolTable}->getSegment($name), $self->{SymbolTable}->indexOf($name));
			$self->{VMWriter}->writeArithmetic('+');
			$output .= $self->handlesymbol('=');
			$output .= $self->compileExpression;
			$output .= $self->handlesymbol(';');
			$self->{VMWriter}->writePop('temp', 0);
			$self->{VMWriter}->writePop('pointer', 1);
			$self->{VMWriter}->writePush('temp', 0);
			$self->{VMWriter}->writePop('that', 0);
		}
		else{
			$output .= $self->handlesymbol('=');
			$output .= $self->compileExpression;
			$output .= $self->handlesymbol(';');
			$self->{VMWriter}->writePop($self->{SymbolTable}->getSegment($name), $self->{SymbolTable}->indexOf($name));
		}
		$output .= "</letStatement>\n";
		return $output;
	}
		
	sub compileExpression{
		my $self = shift;
		my $output = "<expression>\n";
		$output .= $self->compileTerm;	
		while ($self->{Tokenizer}->{token} =~ /$oper/){
			my $op = $self->{Tokenizer}->{token};
			$output .= $self->handlesymbol($oper);
			$output .= $self->compileTerm;
			$self->{VMWriter}->writeArithmetic($op);
		}
		$output .= "</expression>\n";
		return $output;
	}
	
	sub compileExpressionList{
		my $self = shift;
		my $output = "<expressionList>\n";
		my $cnt = 0;	
		while ($self->{Tokenizer}->{token} ne ')'){
			$output .= $self->compileExpression;
			warn "$self->{Tokenizer}->{token}. expected ')'\n" if $self->{Tokenizer}->{token} !~ /^,|\)$/;
			$output .= $self->handlesymbol(',') if $self->{Tokenizer}->{token} eq ',';
			$cnt++;
		}
		$output .= "</expressionList>\n";
		return ($output,$cnt);	
	}
	
	sub compileTerm{
		my $self = shift;
		my $output = "<term>\n";
		my $token_type = $self->{Tokenizer}->tokenType;
		#print $self->{Tokenizer}->{token} . '->' . $token_type . "\n";
		if ($self->{Tokenizer}->{token} =~ /^$identifier$/) {	# variable name
			$next_token  = $self->{Tokenizer}->lookAhead;
			
			if ($next_token eq '['){	# array
				my $name = $self->{Tokenizer}->{token};
				$output .= $self->XMLwrap('identifier', $self->{Tokenizer}->{token});
				$output .= $self->handlesymbol('[');
				$output .= $self->compileExpression;
				$output .= $self->handlesymbol(']');
				$self->{VMWriter}->writePush($self->{SymbolTable}->getSegment($name), $self->{SymbolTable}->indexOf($name));
				$self->{VMWriter}->writeArithmetic('+');
				$self->{VMWriter}->writePop('pointer', 1);
				$self->{VMWriter}->writePush('that', 0);
			}
			elsif ($next_token =~ /^\.|\(/){	# subroutine call
				$output .= $self->compileSubroutineCall;
			}
			elsif ($self->{Tokenizer}->{token} =~ /$keywordConstant/){	# keyword constant
				#print "$self->{Tokenizer}->{token}-------------";
				if ($self->{Tokenizer}->{token} =~ /true|false|null/){
					$self->{VMWriter}->writePush('constant', 0);
					$self->{VMWriter}->writeArithmetic('~') if $self->{Tokenizer}->{token} eq 'true';
				}
			else {	# this
				my $name = $self->{Tokenizer}->{token};
				#print "---$name---".$self->{SymbolTable}->getSegment($name);
				$self->{VMWriter}->writePush($self->{SymbolTable}->getSegment($name), $self->{SymbolTable}->indexOf($name));
				#$self->{VMWriter}->writePush('pointer', 0);
			}
			$output .= $self->XMLwrap('keywordConstant',$self->{Tokenizer}->{token});
		}
			else{	# single variable
				my $name = $self->{Tokenizer}->{token};
				$self->{VMWriter}->writePush($self->{SymbolTable}->getSegment($name), $self->{SymbolTable}->indexOf($name));
				$output .= $self->XMLwrap('identifier', $self->{Tokenizer}->{token});
			}
		}		
		elsif ($self->{Tokenizer}->{token} =~ /^$unaryOp$/){	# unary operation
			my $uo = $self->{Tokenizer}->{token};
			$output .= $self->handlesymbol($unaryOp);
			$output .= $self->compileTerm;
			$self->{VMWriter}->writeArithmetic('~') if $uo eq '~';
			$self->{VMWriter}->justWrite('neg') if $uo eq '-';
		}
		elsif ($self->{Tokenizer}->{token} eq '('){	# expression
			$output .= $self->handlesymbol('(');
			$output .= $self->compileExpression;
			$output .= $self->handlesymbol(')');
		}
		elsif ($token_type eq 'integerConstant'){	# integer
			$self->{VMWriter}->writePush('constant', $self->{Tokenizer}->{token});
			$output .= $self->XMLwrap('integerConstant',$self->{Tokenizer}->{token})
		}
		elsif ($token_type eq 'stringConstant'){	# string
			my $str = $self->{Tokenizer}->{token};
			#print "************** $str ***************\n";
			$str =~ s/^\"(.*)\"$/$1/;
			$strLen = length $str;
			$self->{VMWriter}->writePush('constant', $strLen);
			$self->{VMWriter}->writeCall('String.new', 1);
			foreach (split('',$str)){
				$self->{VMWriter}->writePush('constant', ord $_);
				$self->{VMWriter}->writeCall('String.appendChar', 2);
			}
			$output .= $self->XMLwrap('stringConstant',$self->{Tokenizer}->{token});
		}
		$output .= "</term>\n";
		return $output;
	}
	
	sub handlesymbol(){
		my $self = shift;
		my $symbol = shift;
		my $token = $self->{Tokenizer}->{token};
		#print "s = $symbol\n";print "t = $token\n";
		warn "expected '$symbol'\n" if $token ne $symbol && (length $symbol == 1 || $token !~ /^$symbol$/);
		return $self->XMLwrap('symbol',$token);
	}
	
	sub compileSubroutineCall(){
		my $self = shift;
		my $output;
		my $subName = $self->{Tokenizer}->{token};
		#$self->compileTerm($subName);
		$output .= $self->XMLwrap('identifier', $self->{Tokenizer}->{token});
		my $i = 0;
		if ($self->{Tokenizer}->{token} eq '.'){
			$output .= $self->handlesymbol('.');
			#print "\n----".$self->{SymbolTable}->typeOf($subName)."---\n";
			if ($self->{SymbolTable}->typeOf($subName) ne 'NONE'){
				$self->{VMWriter}->writePush($self->{SymbolTable}->getSegment($subName), $self->{SymbolTable}->indexOf($subName));
				$subName = $self->{SymbolTable}->typeOf($subName);
				$i++;
			}
			$subName .= '.' . $self->{Tokenizer}->{token};
			$output .= $self->XMLwrap('identifier', $self->{Tokenizer}->{token});
		}
		else{
			$self->{VMWriter}->writePush('pointer', 0);
			$subName = $self->{className} . '.' . $subName;
			$i++;
		}
		$subName =~ s/this\./$self->{className}\./;
		$output .= $self->handlesymbol('(');
		my ($xml, $argCnt) = $self->compileExpressionList;
		$output .= $xml;
		$output .= $self->handlesymbol(')');
		$self->{VMWriter}->writeCall($subName,$argCnt+$i);
		return $output;
	}

package Tokenizer;
	sub new { return bless {}, shift; }

	sub load_file {
		my ($self, $fh) = @_;
		while (<$fh>){
			if (!/\"[^\"]*\/\//){
				s/\/\/.*//g;	# // comments
			}
			s/\s*\n//g;		# empty lines
			$self->{file} .= $_ ;
		}	
		$self->{file} =~ s/\/\*+((?!\*+\/).)*\*+\///gs;	# /* comments  
		
		#open FH, '>tmp.dat';
		#print FH $self->{file};
		#close(FH);
	}

	sub getToken(){
		my $self = shift;
		my $file = shift;
		if ($file =~ /^\s*($keyword)[\s|$symbol]/){
			$file =~ s/^\s*($keyword)//;
			return ($1,$file) ;
		}
		return ($1,$file) if $file =~ s/^\s*($symbol)//;
		if ($file =~ /^\s*($integerConstant)[\s|$symbol]/){
			$file =~ s/^\s*($integerConstant)//;
			return ($1,$file);
		}
		if ($file =~ /^\s*($identifier)[\s|$symbol]/){
			$file =~ s/^\s*($identifier)//;
			return ($1,$file);
		}
		if ($file =~ /^\s*($stringConstant)[\s|$symbol]/){
			$file =~ s/^\s*($stringConstant)//;
			return ($1,$file);
		}
	}
	
	sub advance {
		my $self = shift;
		my $file = $self->{file};
		
		($token,$file) = $self->getToken($file);
		$self->{file} = $file;
		return $self->{token} = $token;
	}
	
	sub lookAhead {
		my $self = shift;
		my $file = $self->{file};
		
		($token,$file) = $self->getToken($file);
		return $token;
	}
	
	sub tokenType {
		my $self = shift;
		$_ = $self->{token};
		return 'keyword' if /^($keyword)$/;
		return 'symbol' if /^($symbol)$/;
		return 'integerConstant' if /^($integerConstant)$/;
		return 'stringConstant' if /^($stringConstant)$/;
		#return 'keywordConstant' if /^($keywordConstant)$/;
		return 'identifier' if /^($identifier)$/;
	}
   
	sub keyword {
		my $self = shift;
		my $token_type = $self->tokenType;
		
		$_ = $self->{token};
		return 'CLASS' if /^class/;
		return 'METHOD' if /^method/;
		return 'FUNCTION' if /^function/;
		return 'CONSTRUCTOR' if /^constructor/;
		return 'INT' if /^int/;
		return 'BOOLEAN' if /^boolean/;
		return 'CHAR' if /^char/;
		return 'VOID' if /^void/;
		return 'VAR' if /^var/;
		return 'STATIC' if /^static/;
		return 'FIELD' if /^field/;
		return 'LET' if /^let/;
		return 'DO' if /^do/;
		return 'IF' if /^if/;
		return 'ELSE' if /^else/;
		return 'WHILE' if /^while/;
		return 'RETURN' if /^return/;
		return 'TRUE' if /^true/;
		return 'FALSE' if /^false/;
		return 'NULL' if /^null/;
		return 'THIS' if /^this/;
   }

package SymbolTable;
	our (%methodTable, %classTable, $classStaticIndex, $classFieldIndex, $methodArgIndex, $methodVarIndex );
	sub new { 
		return bless {}, shift; 
	}
	
	sub init {
		my $self = shift;
		#print "*********** init ******************\n";
		$classStaticIndex = 0;
		$classFieldIndex = 0;
		$methodArgIndex = 0;
		$methodVarIndex = 0;
		%classTable = null;
	}
	
	sub resetMethodIndex {
		$methodArgIndex = 0;
		$methodVarIndex = 0;
	}
	
	sub startSubroutine{
		my $self = shift;
		%methodTable = null;
		$methodArgIndex = 0;
		$methodVarIndex = 0;
		$whileIndex = 0;
		$ifIndex = 0;
	}
	
	sub printMethodTable{
		my $self = shift;
		my @keys = keys %methodTable;
		#print "@keys\n";
		foreach $name(@keys){
			print "$name: $methodTable{$name}{type}, $methodTable{$name}{kind}, $methodTable{$name}{index}\n";
		}
	}
	
	sub printClassTable{
		my $self = shift;
		my @keys = keys %classTable;
		#print "@keys\n";
		foreach $name(@keys){
			print "$name: $classTable{$name}{type}, $classTable{$name}{kind}, $classTable{$name}{index}\n";
		}
	}
	
	sub define{
		my ($self, $name, $type, $kind) = @_;
		#print "($self, $name, $type, $kind)\n";
		if ($kind =~ /STATIC|FIELD/){
			$classTable{$name}{type} = $type;
			$classTable{$name}{kind} = $kind;
			$classTable{$name}{index} = $classStaticIndex++ if $kind eq 'STATIC';
			$classTable{$name}{index} = $classFieldIndex++ if $kind eq 'FIELD';
		}
		if ($kind =~ /ARGUMENT|VAR/){
			$methodTable{$name}{type} = $type;
			$methodTable{$name}{kind} = $kind;
			$methodTable{$name}{index} = $methodVarIndex++ if $kind eq 'VAR';
			$methodTable{$name}{index} = $methodArgIndex++ if $kind eq 'ARGUMENT';
		}
		if ($kind =~ /POINTER/){
			$methodTable{$name}{type} = $type;
			$methodTable{$name}{kind} = $kind;
			$methodTable{$name}{index} = 0;
		}
		#$self->printClassTable;
		#print "$tableRow{kind}\n";
		#print $methodTable{$name}{type}."\n";
	}
	
	sub varCount{
		my ($self, $kind) = @_;
		my %table = %classTable if $kind =~ /STATIC|FIELD/;
		%table = %methodTable if $kind =~ /ARGUMENT|VAR/;
		my $cnt = 0;
		foreach $name(keys %table){
			#print "$name=$table{$name}{kind}\n";
			$cnt++ if ($table{$name}{kind} eq $kind);
		}
		return $cnt;
	}
	
	sub kindOf{
		my ($self, $name) = @_;
		return $methodTable{$name}{kind} if defined $methodTable{$name}{kind};
		return $classTable{$name}{kind} if defined $classTable{$name}{kind};
		return 'NONE';
	}
	
	sub typeOf{
		my ($self, $name) = @_;
		return $methodTable{$name}{type} if defined $methodTable{$name}{type};
		return $classTable{$name}{type} if defined $classTable{$name}{type};
		return 'NONE';
	}
	
	sub indexOf{
		my ($self, $name) = @_;
		return $methodTable{$name}{index} if defined $methodTable{$name}{index};
		return $classTable{$name}{index} if defined $classTable{$name}{index};
		return 'NONE';
	}
	
	sub getSegment{
		my ($self, $name) = @_;
		return 'local' if $methodTable{$name}{kind} eq 'VAR';
		return 'argument' if $methodTable{$name}{kind} eq 'ARGUMENT';
		return 'pointer' if $methodTable{$name}{kind} eq 'POINTER';
		return 'static' if $classTable{$name}{kind} eq 'STATIC';
		return 'this' if $classTable{$name}{kind} eq 'FIELD';
		return 'NONE';
	}
	
package VMWriter;
	sub new { return bless {}, shift; }
	
	sub init{
		my ($_self, $file) = @_;
		open(my $fh, '>', $file) or die "Unable to open $file";
		$self->{fh} = $fh;
	}
	
	sub writePush{
		my ($_self, $segment, $index) = @_;
		my $fh = $self->{fh};
		print $fh "push $segment $index\n";
	}
	
	sub writePop{
		my ($_self, $segment, $index) = @_;
		my $fh = $self->{fh};
		print $fh "pop $segment $index\n";
	}
	
	sub justWrite{
		my ($_self, $command) = @_;
		my $fh = $self->{fh};
		print $fh "$command\n";
	}
	
	sub writeArithmetic{	#'\+|\-|\*|\/|\&|\||<|>|=';
		my ($_self, $command) = @_;
		my $fh = $self->{fh};
		print $fh "add\n" if $command eq '+';
		print $fh "sub\n" if $command eq '-';
		print $fh "neg\n" if $command eq 'neg';
		print $fh "call Math.multiply 2\n" if $command eq '*';
		print $fh "call Math.divide 2\n" if $command eq '/';
		print $fh "not\n" if $command eq '~';
		print $fh "gt\n" if $command eq '>';
		print $fh "lt\n" if $command eq '<';
		print $fh "eq\n" if $command eq '=';
		print $fh "and\n" if $command eq '&';
		print $fh "or\n" if $command eq '|';
	}
	
	sub writeLabel{
		my ($_self, $label) = @_;
		my $fh = $self->{fh};
		print $fh "label $label\n";
	}
	
	sub writeGoto{
		my ($_self, $label) = @_;
		my $fh = $self->{fh};
		print $fh "goto $label\n";
	}
	
	sub writeIfGoto{
		my ($_self, $label) = @_;
		my $fh = $self->{fh};
		print $fh "if-goto $label\n";
	}
	
	sub writeCall{
		my ($_self, $name, $nArgs) = @_;
		my $fh = $self->{fh};
		print $fh "call $name $nArgs\n";
	}
	
	sub writeFunction{
		my ($_self, $name, $nLocals) = @_;
		my $fh = $self->{fh};
		print $fh "function $name $nLocals\n";
	}
	
	sub writeReturn{
		my $_self = shift;
		my $fh = $self->{fh};
		print $fh "return\n";
	}
	
	sub close{
		my $_self = shift;
		my $fh = $self->{fh};
		close ($fh);
	}
