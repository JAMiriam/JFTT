/*
 * Kod interpretera maszyny rejestrowej do projektu z JFTT2017
 *
 * Autor: Maciek Gębala
 * http://ki.pwr.edu.pl/gebala/
 * 2017-11-20
*/

#include<iostream>
#include<fstream>

#include<utility>
#include<vector>
#include<map>

#include<cstdlib> 	// rand()
#include<ctime>

using namespace std;

enum Instructions { GET, PUT, LOAD, LOADI, STORE, STOREI, ADD, ADDI, SUB, SUBI, SHR, SHL, INC, DEC, ZERO, JUMP, JZERO, JODD, HALT, ERROR };

int main(int argc, char* argv[])
{
    vector< pair<Instructions,int> > program;
    map<int,long long> pam;

    long long a;
    int lr;

    int k=0;
    long long i;
    Instructions i1;
    int i2;
    string com;

    if( argc!=2 )
    {
	cout << "Sposób użycia programu: interpreter kod" << endl;
	return -1;
    }

    cout << "Czytanie pliku " << argv[1] << endl;
    ifstream plik( argv[1] );
    if( !plik )
    {
	cout << "Błąd: Nie można otworzyć pliku " << argv[1] << endl;
	return -1;
    }
    while( !plik.eof() )
    {
	plik >> com;
	i1 = ERROR;
        i2 = 0;

	if( com=="GET" ) { i1 = GET; }
	if( com=="PUT" ) { i1 = PUT; }

	if( com=="LOAD"  ) { i1 = LOAD; plik >> i2; }
	if( com=="LOADI"  ) { i1 = LOADI; plik >> i2; }
	if( com=="STORE" ) { i1 = STORE; plik >> i2; }
	if( com=="STOREI" ) { i1 = STOREI; plik >> i2; }

	if( com=="ADD"  ) { i1 = ADD; plik >> i2; }
	if( com=="ADDI"  ) { i1 = ADDI; plik >> i2; }
	if( com=="SUB"  ) { i1 = SUB; plik >> i2; }
	if( com=="SUBI"  ) { i1 = SUBI; plik >> i2; }

	if( com=="SHR"  ) { i1 = SHR; }
	if( com=="SHL"  ) { i1 = SHL; }
	if( com=="INC"  ) { i1 = INC; }
	if( com=="DEC"  ) { i1 = DEC; }
	if( com=="ZERO" ) { i1 = ZERO; }

        if( com=="JUMP"  ) { i1 = JUMP; plik >> i2; }
	if( com=="JZERO" ) { i1 = JZERO; plik >> i2; }
	if( com=="JODD"  ) { i1 = JODD; plik >> i2; }
	if( com=="HALT"  ) { i1 = HALT; }

	if( i1==ERROR ) { cout << "Błąd: Nieznana instrukcja w linii " << k << "." << endl; return -1; }
        if( i2<0 ) { cout << "Błąd: Zły adress w instrukcji w linii " << k << endl; return -1; }

	if( plik.good() )
	{
	    program.push_back( make_pair(i1,i2) );
	}
	k++;
    }
    plik.close();
    cout << "Skończono czytanie pliku (" << program.size() << " linii)." << endl;

    cout << "Uruchamianie programu." << endl;
    lr = 0;
    srand(time(NULL));
    a = rand();
    i = 0;
    while( program[lr].first!=HALT )	// HALT
    {
	switch( program[lr].first )
	{
	    case GET:	cout << "? "; cin >> a; i+=100; lr++; break;
	    case PUT:	cout << "> " << a << endl; i+=100; lr++; break;

	    case LOAD:		a = pam[program[lr].second]; i+=10; lr++; break;
	    case LOADI:		a = pam[pam[program[lr].second]]; i+=10; lr++; break;
	    case STORE:		pam[program[lr].second] = a; i+=10; lr++; break;
	    case STOREI:	pam[pam[program[lr].second]] = a; i+=10; lr++; break;

	    case ADD:   a += pam[program[lr].second] ; i+=10; lr++; break;
	    case ADDI:  a += pam[pam[program[lr].second]] ; i+=10; lr++; break;
	    case SUB:   if( a >= pam[program[lr].second] ) a -= pam[program[lr].second];
                        else a = 0;
                        i+=10; lr++; break;
	    case SUBI:  if( a >= pam[pam[program[lr].second]] ) a -= pam[pam[program[lr].second]];
                        else a = 0;
                        i+=10; lr++; break;

	    case SHR:   a >>= 1; i+=1; lr++; break;
	    case SHL:   a <<= 1; i+=1; lr++; break;
	    case INC:   a++ ; i+=1; lr++; break;
	    case DEC:   if( a>0 ) a--; i+=1; lr++; break;
	    case ZERO:  a = 0; i+=1; lr++; break;

	    case JUMP: 	lr = program[lr].second; i+=1; break;
	    case JZERO:	if( a==0 ) lr = program[lr].second; else lr++; i+=1; break;
	    case JODD:	if( a % 2 != 0 ) lr = program[lr].second; else lr++; i+=1; break;
	    default: break;
	}
	if( lr<0 || lr>=(int)program.size() )
	{
	    cout << "Błąd: Wywołanie nieistniejącej instrukcji nr " << lr << "." << endl;
	    return -1;
	}
    }
    cout << "Skończono program (czas: " << i << ")." << endl;

    return 0;
}

