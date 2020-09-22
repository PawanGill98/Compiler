#include <iostream>
#include <string>
#include <cstdlib>

int main() {
    int c = 0;
    for (std::string line; std::getline(std::cin, line);) {
        for (int i = 0; i < line.length(); i++) {
            if ((line[i] == ' ') || (line[i] == '\t')){
            	c++;
            }
            else {
                break;
            }
    	}
    	std::cout << line.substr(c) << std::endl;
    	c = 0;
    }
	exit(EXIT_SUCCESS);
}
