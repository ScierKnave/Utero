#include "utero.h"

tensor sum(tensor x, tensor y) {
    tensor z = talloc(x.shape);
    for (int i = 0; i < x.size; i++){
        z.values[i] = x.values[i] + y.values[i];
    }
    return z;
};

var sum(var x, var y){
    //TODO;
}
